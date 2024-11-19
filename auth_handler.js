function handler(event) {
    var request = event.request;
    var uri = request.uri;

    // Check if it's an auth route request
    if (uri.startsWith('/auth/')) {
        if (uri === '/auth/login') {
            const cognitoDomain = request.headers.host.value.replace(/^[^.]+/, 'auth');
            const redirectUri = `https://${request.headers.host.value}/auth/callback`;
            const loginUrl = `https://${cognitoDomain}/login?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${encodeURIComponent(redirectUri)}`;

            return {
                statusCode: 302,
                headers: {
                    'location': { value: loginUrl }
                }
            };
        }
    }

    return request;
}