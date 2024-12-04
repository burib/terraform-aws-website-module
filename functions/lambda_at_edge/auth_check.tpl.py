import json
import time
import urllib.parse
import base64
import logging
import urllib.request
import urllib.error
from email.utils import formatdate
from boto3.session import Session
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.DEBUG)

# Configuration from Terraform
COGNITO_CLIENT_ID = "${cognito_client_id}"
AUTH_DOMAIN = "${auth_domain}"
PROTECTED_PATHS = json.loads('${protected_paths}') # e.g., ["/dashboard/*", "/admin/*", "/profile/*"]
COGNITO_ISSUER = "${cognito_token_issuer_endpoint}"


# Initialize SSM client outside handler
ssm_client = Session().client('ssm', region_name='us-east-1')
# Cache for SSM parameters
_ssm_cache = {}


def get_parameter_from_ssm(parameter_name):
    """Fetch a parameter from SSM Parameter Store with caching"""
    # Check cache first
    cache_entry = _ssm_cache.get(parameter_name)
    current_time = time.time()

    # If we have a cached value that's less than 5 minutes old, use it
    if cache_entry and (current_time - cache_entry['timestamp'] < 300):
        logger.debug("Using cached SSM parameter")
        return cache_entry['value']

    logger.debug(f"Fetching parameter from SSM: {parameter_name}")
    try:
        response = ssm_client.get_parameter(
            Name=parameter_name,
            WithDecryption=True
        )
        value = response['Parameter']['Value']

        # Update cache
        _ssm_cache[parameter_name] = {
            'value': value,
            'timestamp': current_time
        }

        logger.debug("Successfully retrieved and cached parameter from SSM")
        return value
    except ClientError as e:
        logger.error(f"Error fetching from SSM: {e}")
        # If there's an error but we have a cached value, use it as fallback
        if cache_entry:
            logger.warning("Using cached parameter due to SSM fetch error")
            return cache_entry['value']
        raise

# Pre-fetch the client secret at cold start
try:
    CLIENT_SECRET = get_parameter_from_ssm('/auth/cognito_user_pool_client/main/client_secret')
    logger.debug("Pre-fetched client secret at cold start")
except Exception as e:
    logger.error(f"Failed to pre-fetch client secret: {e}")
    CLIENT_SECRET = None

# Add these functions for JWT validation
def decode_token_segments(token):
    """Decode the JWT segments without verification"""
    try:
        if not token or len(token.split('.')) != 3:
            return None

        header_segment, payload_segment, signature_segment = token.split('.')

        # Add padding if needed and decode header
        header_padding = '=' * (4 - (len(header_segment) % 4))
        header = json.loads(base64.urlsafe_b64decode(header_segment + header_padding).decode('utf-8'))

        # Add padding if needed and decode payload
        payload_padding = '=' * (4 - (len(payload_segment) % 4))
        payload = json.loads(base64.urlsafe_b64decode(payload_segment + payload_padding).decode('utf-8'))

        return {
            'header': header,
            'payload': payload,
            'signature': signature_segment
        }
    except Exception as e:
        logger.error(f"Error decoding token segments: {e}")
        return None


def fetch_jwks():
    """Fetch JWKs from Cognito"""
    try:
        jwks_url = f"{COGNITO_ISSUER}/.well-known/jwks.json"
        logger.debug(f"Fetching JWKS from: {jwks_url}")

        req = urllib.request.Request(jwks_url)
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode('utf-8'))
    except Exception as e:
        logger.error(f"Error fetching JWKS: {e}")
        return None

def validate_token(token):
    """Validate the essential claims of Cognito ID token"""
    logger.debug("Starting token validation")

    # First fetch fresh JWKS
    jwks = fetch_jwks()
    if not jwks:
        logger.error("Failed to fetch JWKS")
        return False

    segments = decode_token_segments(token)
    if not segments:
        logger.error("Failed to decode token segments")
        return False

    now = int(time.time())
    payload = segments['payload']
    logger.debug(f"Token payload: {json.dumps(payload)}")

    try:
        # 1. Check expiration (REQUIRED)
        if payload['exp'] < now:
            logger.error(f"Token expired. Expiration: {payload['exp']}, Current time: {now}")
            return False

        # 2. Check issuer (REQUIRED)
        if payload['iss'] != COGNITO_ISSUER:
            logger.error(f"Invalid issuer. Expected: {COGNITO_ISSUER}, Got: {payload['iss']}")
            return False

        # 3. Check audience (REQUIRED)
        if payload['aud'] != COGNITO_CLIENT_ID:
            logger.error(f"Invalid audience. Expected: {COGNITO_CLIENT_ID}, Got: {payload['aud']}")
            return False

        # 4. Check token use (Cognito-specific)
        if payload['token_use'] != 'id':
            logger.error(f"Invalid token_use. Expected: id, Got: {payload['token_use']}")
            return False

        logger.debug("Token validation passed")
        return True

    except Exception as e:
        logger.error(f"Error during token validation: {e}")
        return False

def is_path_protected(path):
    """Check if a path matches any protected path pattern"""
    logger.debug(f"Checking if path '{path}' is protected")
    logger.debug(f"Protected paths: {PROTECTED_PATHS}")
    for protected_path in PROTECTED_PATHS:
        if protected_path.endswith('/*'):
            if path.startswith(protected_path[:-1]):
                logger.debug(f"Path '{path}' matches protected pattern '{protected_path}'")
                return True
        elif path == protected_path:
            logger.debug(f"Path '{path}' exactly matches protected path '{protected_path}'")
            return True
    logger.debug(f"Path '{path}' is not protected")
    return False

def create_response(status, headers=None):
    """Create CloudFront response with optional headers"""
    response = {'status': str(status)}
    if headers:
        response['headers'] = {
            k: [{'key': k, 'value': v}] for k, v in headers.items()
        }
    logger.debug(f"Created response: {json.dumps(response)}")
    return response

def exchange_code_for_tokens(code, client_secret, request_domain):
    """Exchange authorization code for tokens"""
    token_endpoint = f"https://{AUTH_DOMAIN}/oauth2/token"
    logger.debug(f"Exchanging code for tokens with endpoint: {token_endpoint}")
    logger.debug(f"Using request domain: {request_domain}")

    redirect_uri = f"https://{request_domain}/auth/callback"
    logger.debug(f"Using redirect URI: {redirect_uri}")

    data = urllib.parse.urlencode({
        'grant_type': 'authorization_code',
        'client_id': COGNITO_CLIENT_ID,
        'client_secret': client_secret,
        'code': code,
        'redirect_uri': redirect_uri
    }).encode('utf-8')

    auth_string = base64.b64encode(
        f"{COGNITO_CLIENT_ID}:{client_secret}".encode('utf-8')
    ).decode('utf-8')

    req = urllib.request.Request(token_endpoint, data=data, method='POST')
    req.add_header('Content-Type', 'application/x-www-form-urlencoded')
    req.add_header('Authorization', f'Basic {auth_string}')

    try:
        logger.debug("Making token exchange request")
        with urllib.request.urlopen(req) as response:
            tokens = json.loads(response.read().decode('utf-8'))
            logger.debug("Successfully exchanged code for tokens")
            return tokens
    except urllib.error.URLError as e:
        logger.error(f"Error exchanging code: {e}")
        if hasattr(e, 'read'):
            error_details = e.read().decode('utf-8')
            logger.error(f"Error response: {error_details}")
        raise

def parse_cookies(cookie_headers):
    """Parse cookies from request headers"""
    logger.debug(f"Parsing cookies from headers: {json.dumps(cookie_headers)}")
    cookies = {}
    if cookie_headers:
        for header in cookie_headers:
            cookie_pairs = header['value'].split(';')
            for pair in cookie_pairs:
                if '=' in pair:
                    key, value = pair.split('=', 1)
                    cookies[key.strip()] = value.strip()
    logger.debug(f"Parsed cookies: {json.dumps(cookies)}")
    return cookies

def encode_state(url):
    """Encode URL for state parameter"""
    logger.debug(f"Encoding state from URL: {url}")
    encoded = base64.urlsafe_b64encode(url.encode()).decode()
    logger.debug(f"Encoded state: {encoded}")
    return encoded

def decode_state(state):
    """Decode state parameter back to URL"""
    logger.debug(f"Decoding state: {state}")
    try:
        decoded = base64.urlsafe_b64decode(state.encode()).decode()
        logger.debug(f"Decoded state: {decoded}")
        return decoded
    except Exception as e:
        logger.error(f"Error decoding state: {e}")
        return None

def parse_token_exp(token):
    """Parse JWT token and return expiration timestamp"""
    try:
        # Split the token and get the payload part (second segment)
        payload_segment = token.split('.')[1]

        # Add padding if needed
        padding = '=' * (4 - (len(payload_segment) % 4))
        payload_segment = payload_segment + padding

        # Decode payload
        payload = json.loads(base64.urlsafe_b64decode(payload_segment).decode('utf-8'))
        return payload.get('exp')
    except Exception as e:
        logger.error(f"Error parsing token expiration: {e}")
        return None

def format_cookie_date(timestamp):
    """Convert Unix timestamp to cookie-compatible date format"""
    return formatdate(timestamp, usegmt=True)

def create_cookie_header(name, value, expiration=None, path="/"):
    """Create a cookie header with security attributes and expiration"""
    cookie = f"{name}={value}; Secure; HttpOnly; SameSite=Lax; Path={path}"
    if expiration:
        cookie += f"; Expires={format_cookie_date(expiration)}"
    return cookie

# Update the handler function's protected path check
def handler(event, context):
    """Main Lambda handler"""
    logger.debug(f"Received event: {json.dumps(event)}")

    request = event['Records'][0]['cf']['request']
    request_domain = request['headers'].get('host', [{'value': None}])[0]['value']

    logger.debug(f"Processing request for URI: {request['uri']}")
    logger.debug(f"Request domain: {request_domain}")

    # Handle auth routes
    if request['uri'].startswith('/auth/'):
        logger.debug("Processing auth route")

        # Handle callback with authorization code
        if request['uri'] == '/auth/callback':
            logger.debug("Processing callback")
            query_params = dict(urllib.parse.parse_qsl(request.get('querystring', '')))
            logger.debug(f"Callback query parameters: {json.dumps(query_params)}")

            if 'code' in query_params:
                try:
                    # Exchange code for tokens
                    tokens = exchange_code_for_tokens(
                        code=query_params['code'],
                        client_secret=CLIENT_SECRET or get_parameter_from_ssm('/auth/cognito_user_pool_client/main/client_secret'),
                        request_domain=request_domain
                    )

                    # Get original URL from state or default to home
                    original_url = decode_state(query_params.get('state', '')) or '/'
                    logger.debug(f"Redirecting to original URL: {original_url}")

                    # Parse expiration times from tokens
                    id_token_exp = parse_token_exp(tokens['id_token'])
                    access_token_exp = parse_token_exp(tokens['access_token'])

                    # Create cookie headers with appropriate expirations
                    cookies = [
                        create_cookie_header('id_token', tokens['id_token'], id_token_exp),
                        create_cookie_header('access_token', tokens['access_token'], access_token_exp),
                    ]

                    # For refresh token, you might want to set a longer expiration
                    # or use the expiration from the token if provided
                    refresh_token_exp = parse_token_exp(tokens['refresh_token'])
                    if refresh_token_exp:
                        cookies.append(create_cookie_header('refresh_token', tokens['refresh_token'], refresh_token_exp))
                    else:
                        # If no expiration in refresh token, set a reasonable default (e.g., 1 hour)
                        one_hour = int(time.time()) + (60 * 60)
                        cookies.append(create_cookie_header('refresh_token', tokens['refresh_token'], one_hour))

                    response = create_response(302, {
                        'Location': original_url,
                        'Set-Cookie': cookies
                    })
                    logger.debug(f"Created redirect response with cookies: {json.dumps(response)}")
                    return response
                except Exception as e:
                    logger.error(f"Error during token exchange: {str(e)}")
                    return create_response(302, {
                        'Location': f"/auth/error?message={urllib.parse.quote(str(e))}"
                    })

        # Handle logout
        elif request['uri'] == '/auth/logout':
            logger.debug("Processing logout")
            logout_url = (
                f"https://{AUTH_DOMAIN}/logout?"
                f"client_id={COGNITO_CLIENT_ID}&"
                f"logout_uri=https://{request_domain}"
            )
            logger.debug(f"Redirecting to logout URL: {logout_url}")
            return create_response(302, {
                'Location': logout_url,
                'Set-Cookie': [
                    f"{cookie}=; Max-Age=0; Secure; HttpOnly; SameSite=Lax; Path=/"
                    for cookie in ['id_token', 'access_token', 'refresh_token']
                ]
            })

        # Handle errors
        elif request['uri'] == '/auth/error':
            logger.debug("Displaying error page")
            return {
                'status': '200',
                'headers': {
                    'content-type': [{'key': 'Content-Type', 'value': 'text/html'}]
                },
                'body': '<html><body><h1>Authentication Error</h1><p>Please try again or contact support.</p></body></html>'
            }

    # Check for protected paths
    elif is_path_protected(request['uri']):
        logger.debug("Checking authentication for protected path")
        cookies = parse_cookies(request.get('headers', {}).get('cookie', []))
        logger.debug(f"Found cookies: {json.dumps(list(cookies.keys()))}")

        if 'id_token' not in cookies or not validate_token(cookies['id_token']):
            # Store current path in state
            state = encode_state(request['uri'])
            logger.debug(f"No auth token found. State encoded from: {request['uri']}")
            login_url = (
                f"https://{AUTH_DOMAIN}/login?"
                f"client_id={COGNITO_CLIENT_ID}&"
                f"response_type=code&"
                f"scope=email+openid+profile&"
                f"state={state}&"
                f"redirect_uri=https://{request_domain}/auth/callback"
            )
            logger.debug(f"Redirecting to login URL: {login_url}")
            return create_response(302, {'Location': login_url})
        else:
            logger.debug("Auth token found, allowing request")

    # Pass through request if not protected or already authenticated
    logger.debug("Passing through request")
    return request