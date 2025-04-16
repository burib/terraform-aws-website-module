locals {
  region     = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id
  times = {
    oneHour  = 3600
    oneDay   = 86400
    oneWeek  = 604800
    oneMonth = 2592000
  }

  bucket_name  = "${var.domain_name}-${random_id.bucket_suffix.hex}"
  s3_origin_id = "S3-${local.bucket_name}"
  www_domain   = "www.${var.domain_name}"
  sanitized_domain_name = replace(var.domain_name, ".", "-")

  cache_settings = {
    static = {
      min_ttl     = local.times.oneDay
      default_ttl = local.times.oneWeek
      max_ttl     = local.times.oneMonth
      compress    = true
    }
    dynamic = {
      min_ttl     = 0
      default_ttl = local.times.oneHour
      max_ttl     = local.times.oneDay
      compress    = true
    }
  }

  static_paths = ["*.css", "*.js", "*.jpg", "*.jpeg", "*.png", "*.gif", "*.ico", "*.svg", "*.woff", "*.woff2", "*.ttf", "*.eot"]
  error_pages = {
    "error_403.html" = {
      error_code = 403
      title      = "Access Denied"
      message    = "You don't have permission to access this page."
    }
    "error_404.html" = {
      error_code = 404
      title      = "Page Not Found"
      message    = "The page you're looking for doesn't exist."
    }
    "error_500.html" = {
      error_code = 500
      title      = "Server Error"
      message    = "Something went wrong on our end."
    }
    "error_503.html" = {
      error_code = 503
      title      = "Service Unavailable"
      message    = "The service is temporarily unavailable. Please try again later."
    }
  }
  html_pages = {
    "index.html" = {
      title   = "Home"
      content = <<-HTML
                <!DOCTYPE html>
                <html lang="en" style="min-height: 100%; margin: 0; padding: 0;">
                <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>${var.domain_name} - Launch Your SaaS in Hours, Not Months</title>
                    <style>
                        body {
                            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif;
                            min-height: 100vh;
                            margin: 0;
                            padding: 0;
                            display: flex;
                            flex-direction: column;
                            background-image: linear-gradient(45deg, #6E5DC6 2%, #E774BB 100%);
                            background-size: cover;
                            background-position: center center;
                            color: white;
                            line-height: 1.6;
                        }

                        .nav {
                            background-color: rgba(0, 0, 0, 0.2);
                            backdrop-filter: blur(8px);
                            padding: 1rem 2rem;
                            display: flex;
                            justify-content: space-between;
                            align-items: center;
                            position: fixed;
                            width: 100%;
                            box-sizing: border-box;
                            top: 0;
                            z-index: 1000;
                        }

                        .nav-logo {
                            font-size: 1.25rem;
                            font-weight: 600;
                            color: white;
                            text-decoration: none;
                        }

                        .nav-links {
                            display: flex;
                            gap: 2rem;
                            align-items: center;
                        }

                        /* Mobile menu button */
                        .mobile-menu-button {
                            display: none;
                            background: none;
                            border: none;
                            color: white;
                            cursor: pointer;
                            padding: 0.5rem;
                        }

                        .nav-link {
                            color: rgba(255, 255, 255, 0.9);
                            text-decoration: none;
                            font-size: 0.875rem;
                            font-weight: 500;
                            transition: all 0.2s;
                            padding: 0.5rem 1rem;
                            border-radius: 6px;
                        }

                        .nav-link:hover {
                            background: rgba(255, 255, 255, 0.1);
                            color: white;
                        }

                        .nav-link.primary {
                            background: white;
                            color: #6E5DC6;
                            padding: 0.75rem 1.5rem;
                            border-radius: 6px;
                            font-weight: 600;
                            transition: all 0.2s ease;
                        }

                        .nav-link.primary:hover {
                            transform: translateY(-1px);
                            background: rgba(255, 255, 255, 0.95);
                            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
                        }

                        /* Mobile styles */
                        @media (max-width: 768px) {
                            .mobile-menu-button {
                                display: block;
                            }

                            .nav-links {
                                display: none;
                                position: absolute;
                                top: 100%;
                                left: 0;
                                right: 0;
                                background: rgba(0, 0, 0, 0.95);
                                backdrop-filter: blur(8px);
                                flex-direction: column;
                                padding: 1rem;
                                gap: 1rem;
                            }

                            .nav-links.active {
                                display: flex;
                            }

                            .nav-link {
                                width: 100%;
                                text-align: center;
                                padding: 1rem;
                            }

                            .nav-link.primary {
                                width: auto;
                                margin: 0.5rem 1rem;
                            }
                        }

                        .main-content {
                            flex: 1;
                            margin-top: 4rem;
                            padding: 4rem 2rem;
                        }

                        .container {
                            max-width: 1200px;
                            margin: 0 auto;
                        }

                        .hero {
                            text-align: center;
                            margin-bottom: 4rem;
                        }

                        h1 {
                            font-size: clamp(2.5rem, 5vw, 4rem);
                            margin-bottom: 1.5rem;
                            text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3);
                            line-height: 1.2;
                        }

                        .subtitle {
                            font-size: clamp(1.25rem, 2.5vw, 1.5rem);
                            opacity: 0.9;
                            margin-bottom: 2rem;
                            max-width: 800px;
                            margin-left: auto;
                            margin-right: auto;
                        }

                        .features-grid {
                            display: grid;
                            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                            gap: 2rem;
                            margin: 4rem 0;
                        }

                        .feature-card {
                            background: rgba(0, 0, 0, 0.2);
                            padding: 2rem;
                            border-radius: 12px;
                            transition: transform 0.2s ease;
                        }

                        .feature-card:hover {
                            transform: translateY(-4px);
                        }

                        .feature-title {
                            display: flex;
                            align-items: center;
                            gap: 0.75rem;
                            margin-bottom: 1rem;
                        }

                        .feature-badge {
                            background: rgba(255, 255, 255, 0.1);
                            padding: 0.25rem 0.75rem;
                            border-radius: 1rem;
                            font-size: 0.875rem;
                            font-weight: 500;
                        }

                        .feature-card h3 {
                            margin: 0;
                            font-size: 1.25rem;
                        }

                        .feature-card p {
                            margin: 0;
                            opacity: 0.9;
                            font-size: 0.9375rem;
                        }

                        .signup-section {
                            background: rgba(0, 0, 0, 0.2);
                            padding: 4rem 2rem;
                            text-align: center;
                            border-radius: 12px;
                            margin-top: 4rem;
                        }

                        .waitlist-form {
                            max-width: 500px;
                            margin: 2rem auto 0;
                        }

                        .email-input {
                            width: 100%;
                            padding: 1rem;
                            border: 1px solid rgba(255, 255, 255, 0.2);
                            background: rgba(255, 255, 255, 0.1);
                            border-radius: 6px;
                            color: white;
                            font-size: 1rem;
                            margin-bottom: 1rem;
                            box-sizing: border-box;
                        }

                        .email-input::placeholder {
                            color: rgba(255, 255, 255, 0.5);
                        }

                        .cta-button {
                            width: 100%;
                            padding: 1rem;
                            background: white;
                            color: #6E5DC6;
                            border: none;
                            border-radius: 6px;
                            font-size: 1rem;
                            font-weight: 600;
                            cursor: pointer;
                            transition: all 0.2s ease;
                        }

                        .cta-button:hover {
                            transform: translateY(-2px);
                            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
                        }

                        .tech-badge {
                            font-size: 0.875rem;
                            background: rgba(255, 255, 255, 0.1);
                            padding: 0.5rem 1rem;
                            border-radius: 2rem;
                            margin: 0.5rem;
                            display: inline-block;
                        }

                        .qr-desktop {
                          position: fixed;
                          bottom: 20px;
                          right: 20px;
                          background: rgba(255, 255, 255, 0.9);
                          padding: 10px;
                          border-radius: 8px;
                          box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1);
                          display: flex;
                          flex-direction: column;
                          align-items: center;
                          gap: 8px;
                          z-index: 1000;
                          font-size: 12px;
                          color: #333;
                          transition: transform 0.2s ease;
                        }

                        .qr-desktop:hover {
                          transform: translateY(-4px);
                        }

                        @media (max-width: 768px) {
                          .qr-desktop {
                            display: none;
                          }
                        }
                    </style>
                </head>
                <body>
                  <nav class="nav">
                      <a href="/" class="nav-logo">${var.domain_name}</a>
                      <button class="mobile-menu-button" aria-label="Toggle menu">
                          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                              <line x1="3" y1="12" x2="21" y2="12"></line>
                              <line x1="3" y1="6" x2="21" y2="6"></line>
                              <line x1="3" y1="18" x2="21" y2="18"></line>
                          </svg>
                      </button>
                      <div class="nav-links" id="nav-links">
                          <a href="#features" class="nav-link">Services</a>
                          <a href="#pricing" class="nav-link">Pricing</a>
                          <a href="#docs" class="nav-link">Documentation</a>
                          <a href="/dashboard/index.html" class="nav-link primary">Start Building →</a>
                      </div>
                  </nav>

                  <main class="main-content">
                      <div class="container">
                          <div class="hero">
                              <h1>Launch Your SaaS in Hours<br>Not Months</h1>
                              <div class="subtitle">
                                  Save $15,000+ in development costs with our production-ready AWS infrastructure.<br/>
                                  Enterprise-grade auth, payments, and monitoring — launch your SaaS in hours, not months.
                              </div>

                              <div>
                                  <span class="tech-badge">AWS Cloud</span>
                                  <span class="tech-badge">LemonSqueezy Ready</span>
                                  <span class="tech-badge">Multi-tenant</span>
                                  <span class="tech-badge">Production-grade</span>
                              </div>
                          </div>

                          <div class="features-grid">
                              <div class="feature-card">
                                  <div class="feature-title">
                                      <span class="feature-badge">Infrastructure</span>
                                  </div>
                                  <h3>Production-Ready Architecture</h3>
                                  <p>Enterprise-grade AWS setup with API Gateway, Lambda, and DynamoDB. Scalable from day one, ready for thousands of users.</p>
                              </div>

                              <div class="feature-card">
                                  <div class="feature-title">
                                      <span class="feature-badge">Payments</span>
                                  </div>
                                  <h3>LemonSqueezy Integration</h3>
                                  <p>Modern billing system with subscriptions, usage tracking, and customer portal. No payment headaches, just happy customers.</p>
                              </div>

                              <div class="feature-card">
                                  <div class="feature-title">
                                      <span class="feature-badge">Auth</span>
                                  </div>
                                  <h3>Secure Authentication</h3>
                                  <p>Built-in Cognito authentication with social logins, MFA, and custom branded login pages. Enterprise-grade security out of the box.</p>
                              </div>

                              <div class="feature-card">
                                  <div class="feature-title">
                                      <span class="feature-badge">Speed</span>
                                  </div>
                                  <h3>Launch Faster</h3>
                                  <p>Skip weeks of setup and configuration. Get your SaaS in front of customers quickly and iterate based on real feedback.</p>
                              </div>

                              <div class="feature-card">
                                  <div class="feature-title">
                                      <span class="feature-badge">Monitoring</span>
                                  </div>
                                  <h3>Full Observability</h3>
                                  <p>Built-in CloudWatch dashboards, logs, and alerts. Know exactly how your SaaS is performing at all times.</p>
                              </div>

                              <div class="feature-card">
                                  <div class="feature-title">
                                      <span class="feature-badge">Branding</span>
                                  </div>
                                  <h3>Custom Domain Ready</h3>
                                  <p>Professional setup with Route 53, CloudFront CDN, and SSL. Your brand, your domain, zero config needed.</p>
                              </div>
                          </div>

                          <div class="signup-section">
                              <h2>Be First to Know When We Launch</h2>
                              <p>Get updates about the progress! Maximum one update per week!</p>
                              <iframe
                                  src="https://forms.gle/nh5ea74aVTiwtvrp9"
                                  width="100%"
                                  height="950"
                                  frameborder="0"
                                  marginheight="0"
                                  marginwidth="0">
                                  Loading...
                              </iframe>
                          </div>
                         <!--
                          <div class="signup-section">
                              <h2>Launch Your SaaS Faster</h2>
                              <p>Join the waitlist for updates. </p>
                              https://forms.gle/nh5ea74aVTiwtvrp9
                              <div class="waitlist-form">
                                  <form id="signup" onsubmit="event.preventDefault();">
                                      <input type="email" class="email-input" placeholder="Enter your email" required>
                                      <button type="submit" class="cta-button">Get Early Access →</button>
                                  </form>
                              </div>
                          </div>
                          -->
                      </div>
                  </main>

                  <div class="qr-desktop">
                      <img
                          src="https://api.qrserver.com/v1/create-qr-code/?size=100x100&data=https://${var.domain_name}"
                          width="100"
                          height="100"
                          alt="Scan to view on mobile"
                      />
                      <span>View on mobile</span>
                  </div>

                  <script>
                      document.addEventListener('DOMContentLoaded', function() {
                          // Mobile menu functionality
                          const mobileMenuButton = document.querySelector('.mobile-menu-button');
                          const navLinks = document.getElementById('nav-links');

                          function toggleMenu() {
                              navLinks.classList.toggle('active');
                          }

                          if (mobileMenuButton) {
                              mobileMenuButton.addEventListener('click', toggleMenu);
                          }

                          // Close menu when clicking links
                          document.querySelectorAll('.nav-link').forEach(link => {
                              link.addEventListener('click', () => {
                                  navLinks.classList.remove('active');
                              });
                          });

                          // Close menu when clicking outside
                          document.addEventListener('click', (e) => {
                              if (!e.target.closest('.nav') && navLinks.classList.contains('active')) {
                                  navLinks.classList.remove('active');
                              }
                          });

                          // Signup form handling
                          const signupForm = document.getElementById('signup');
                          if (signupForm) {
                              signupForm.addEventListener('submit', function(e) {
                                  e.preventDefault();
                                  // Add your signup handling logic here
                                  console.log('Signup submitted');
                              });
                          }
                      });
                  </script>
              </body>
                </html>
                HTML
    }
    "auth/callback/index.html" = {
      title   = "Authentication Callback"
      content = <<-HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Authentication - ${var.domain_name}</title>
        <script>
            // Store the auth code when received
            function handleCallback() {
                const urlParams = new URLSearchParams(window.location.search);
                const code = urlParams.get('code');
                const state = urlParams.get('state');

                if (code) {
                    // Store auth code with timestamp
                    sessionStorage.setItem('auth_code', code);
                    sessionStorage.setItem('auth_timestamp', Date.now().toString());

                    // Redirect to original path or dashboard
                    const redirectPath = state ?
                        decodeURIComponent(state) :
                        '/dashboard';

                    window.location.href = redirectPath;
                } else {
                    // Handle error
                    window.location.href = '/auth/error.html';
                }
            }

            // Execute on load
            window.onload = handleCallback;
        </script>
    </head>
    <body>
        <div>Processing authentication...</div>
    </body>
    </html>
  HTML
    }
    "auth/index.html" = {
      title   = "Authentication Callback"
      content = <<-HTML
              <!DOCTYPE html>
            <html lang="en" style="min-height: 100%; margin: 0; padding: 0;">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Authentication Check - ${var.domain_name}</title>
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif;
                        min-height: 100vh;
                        margin: 0;
                        padding: 0;
                        display: flex;
                        flex-direction: column;
                        justify-content: center;
                        align-items: center;
                        background-color: rgb(168, 105, 193);
                        background-image: url("https://d2k1ftgv7pobq7.cloudfront.net/images/backgrounds/gradients/rainbow.svg");
                        background-size: cover;
                        background-position: center center;
                        color: white;
                        text-align: center;
                    }

                    .container {
                        padding: 2rem;
                        max-width: 800px;
                        width: 90%;
                    }

                    #loading {
                        font-size: 1.2rem;
                    }

                    .spinner {
                        display: inline-block;
                        width: 50px;
                        height: 50px;
                        border: 3px solid rgba(255,255,255,.3);
                        border-radius: 50%;
                        border-top-color: white;
                        animation: spin 1s ease-in-out infinite;
                        margin: 1rem;
                    }

                    @keyframes spin {
                        to { transform: rotate(360deg); }
                    }
                </style>
                <script>

                    // Get stored authentication data
                    function getStoredAuth() {
                        const code = sessionStorage.getItem('auth_code');
                        const timestamp = sessionStorage.getItem('auth_timestamp');

                        if (!code || !timestamp) return null;

                        // Check if auth code is expired (24 hours)
                        const expiryTime = parseInt(timestamp) + (24 * 60 * 60 * 1000);
                        if (Date.now() > expiryTime) {
                            sessionStorage.removeItem('auth_code');
                            sessionStorage.removeItem('auth_timestamp');
                            return null;
                        }

                        return code;
                    }

                    // Redirect to Cognito login
                    function redirectToLogin() {
                        window.location.href = "${var.auth_urls.hosted_ui_login_url}";
                    }

                    // Main authentication check
                    async function checkAuthentication() {
                        const authCode = getStoredAuth();

                        if (!authCode) {
                            redirectToLogin();
                            return;
                        }

                        // Auth successful, redirect to dashboard or protected content
                        window.location.href = '/dashboard/index.html';
                    }

                    // Initialize when page loads
                    window.onload = () => {
                        setTimeout(checkAuthentication, 1000); // Short delay for visual feedback
                    };
                </script>
            </head>
            <body>
                <div class="container">
                    <div class="spinner"></div>
                    <div id="loading">Checking authentication...</div>
                </div>
            </body>
            </html>
          HTML
    }
    "auth/error.html" = {
      title   = "Authentication Error"
      content = <<-HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Authentication Error - ${var.domain_name}</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    min-height: 100vh;
                    margin: 0;
                    background-color: #f9fafb;
                }
                .container {
                    text-align: center;
                    padding: 2rem;
                }
                h1 { color: #111827; }
                p { color: #6b7280; }
                .button {
                    display: inline-block;
                    margin-top: 1rem;
                    padding: 0.5rem 1rem;
                    background-color: #3b82f6;
                    color: white;
                    text-decoration: none;
                    border-radius: 0.375rem;
                    transition: background-color 0.2s;
                }
                .button:hover {
                    background-color: #2563eb;
                }
                .cta-button {
                    width: 100%;
                    padding: 1rem;
                    background: white;
                    color: #6E5DC6;
                    border: none;
                    border-radius: 6px;
                    font-size: 1rem;
                    font-weight: 600;
                    cursor: pointer;
                    transition: all 0.2s ease;
                }

                .cta-button:hover {
                    transform: translateY(-2px);
                    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>Authentication Error</h1>
                <p>Sorry, we couldn't complete the authentication process.</p>
                <a href="${var.auth_urls.callback}" class="button cta-button">Try Again</a>
            </div>
        </body>
        </html>
      HTML
    }
    "dashboard/index.html" = {
      title   = "Dashboard"
      content = <<-HTML
        <!DOCTYPE html>
        <html lang="en">
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard | ${var.domain_name}</title>
    <style>
       body {
           font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif;
           margin: 0;
           padding: 0;
           background: #f8fafc;
       }

       .app {
           display: grid;
           grid-template-columns: 240px 1fr;
           min-height: 100vh;
       }

       .sidebar {
           background: white;
           border-right: 1px solid #e2e8f0;
           padding: 24px;
       }

       .logo {
           font-weight: 600;
           margin-bottom: 32px;
       }

       .nav-items {
           list-style: none;
           padding: 0;
           margin: 0;
       }

       .nav-item a {
           display: flex;
           align-items: center;
           padding: 12px;
           color: #64748b;
           text-decoration: none;
           border-radius: 6px;
           margin-bottom: 4px;
       }

       .nav-item a:hover {
           background: #f1f5f9;
       }

       .nav-item a.active {
           background: #f1f5f9;
           color: #6E5DC6;
           font-weight: 500;
       }

       .main {
           padding: 32px;
       }

       .header {
           display: flex;
           justify-content: space-between;
           align-items: center;
           margin-bottom: 32px;
       }

       .step-action {
           background: #6E5DC6;
           color: white;
           border: none;
           padding: 8px 16px;
           border-radius: 6px;
           font-weight: 500;
           cursor: pointer;
           transition: all 0.2s ease;
       }

       .step-action:hover {
           background: #5d4db3;
           transform: translateY(-1px);
       }

       .apps-list {
           background: white;
           border-radius: 8px;
           border: 1px solid #e2e8f0;
           margin-bottom: 24px;
       }

       .app-item {
           display: grid;
           grid-template-columns: 1fr auto auto;
           padding: 16px 24px;
           border-bottom: 1px solid #e2e8f0;
           align-items: center;
           gap: 16px;
       }

       .app-info h3 {
           margin: 0 0 4px;
           color: #1e293b;
       }

       .app-meta {
           font-size: 14px;
           color: #64748b;
       }

       .tech-badge {
           background: #f1f5f9;
           padding: 4px 8px;
           border-radius: 4px;
           font-size: 12px;
           margin-right: 8px;
           color: #475569;
       }

       .status {
           color: #64748b;
       }

       .modal {
           position: fixed;
           inset: 0;
           background: rgba(0,0,0,0.5);
           display: flex;
           align-items: center;
           justify-content: center;
           display: none;
           padding: 16px;
       }

       .modal.show {
           display: flex;
       }

       .modal-content {
           background: white;
           padding: 24px;
           border-radius: 8px;
           width: 100%;
           max-width: 500px;
           box-shadow: 0 20px 25px -5px rgb(0 0 0 / 0.1);
       }

       .modal-content h2 {
           margin-top: 0;
           color: #1e293b;
       }

       .form-group {
           margin-bottom: 16px;
       }

       .form-group label {
           display: block;
           margin-bottom: 8px;
           font-weight: 500;
           color: #1e293b;
       }

       .form-control {
           width: 100%;
           padding: 8px 12px;
           border: 1px solid #e2e8f0;
           border-radius: 6px;
           font-size: 14px;
           box-sizing: border-box;
       }

       .form-control:focus {
           outline: none;
           border-color: #6E5DC6;
           box-shadow: 0 0 0 1px #6E5DC6;
       }

       .form-group select {
           width: 100%;
           padding: 8px 12px;
           border: 1px solid #e2e8f0;
           border-radius: 6px;
           font-size: 14px;
           background: white;
       }

       @media (max-width: 768px) {
           .app {
               grid-template-columns: 1fr;
           }

           .sidebar {
               display: none;
           }

           .main {
               padding: 16px;
           }

           .app-item {
               grid-template-columns: 1fr;
               gap: 8px;
           }

           .header {
               flex-direction: column;
               gap: 16px;
               align-items: stretch;
               text-align: center;
           }
    </style>
</head>
<body>
    <div class="app">
        <!-- Sidebar -->
        <nav class="sidebar">
            <div class="logo">${var.domain_name}</div>
            <ul class="nav-items">
                <li class="nav-item">
                    <a href="#" class="active">Getting Started</a>
                </li>
                <li class="nav-item">
                    <a href="#">Infrastructure</a>
                </li>
                <li class="nav-item">
                    <a href="#">Domain Settings</a>
                </li>
                <li class="nav-item">
                    <a href="#">Authentication</a>
                </li>
                <li class="nav-item">
                    <a href="#">Settings</a>
                </li>
            </ul>
        </nav>

        <!-- Main content -->
<main class="main">
           <header class="header">
               <h1>Your SaaS Applications</h1>
               <button class="step-action" onclick="showNewAppModal()">Create New SaaS</button>
           </header>

           <div class="apps-list">
               <div class="app-item">
                   <div class="app-info">
                       <h3>app1.example.com</h3>
                       <div class="app-meta">
                           <span class="tech-badge">React</span>
                           <span class="tech-badge">Python</span>
                           Created 2 days ago
                       </div>
                   </div>
                   <span class="status">Deploying...</span>
                   <button class="step-action">Manage</button>
               </div>
               <div class="app-item">
                   <div class="app-info">
                       <h3>app2.example.com</h3>
                       <div class="app-meta">
                           <span class="tech-badge">Angular</span>
                           <span class="tech-badge">Node.js</span>
                           Created 5 days ago
                       </div>
                   </div>
                   <span class="status">Active</span>
                   <button class="step-action">Manage</button>
               </div>
           </div>

           <div class="modal" id="newAppModal">
               <div class="modal-content">
                   <h2>Create New SaaS Application</h2>
                   <form onsubmit="event.preventDefault();">
                       <div class="form-group">
                           <label>Domain Name</label>
                           <input type="text" class="form-control" placeholder="app.yourdomain.com">
                       </div>

                       <div class="form-group">
                           <label>Frontend Framework</label>
                           <select class="form-control">
                               <option value="react">React</option>
                               <option value="angular">Angular</option>
                           </select>
                       </div>

                       <div class="form-group">
                           <label>Backend Runtime</label>
                           <select class="form-control">
                               <option value="python">Python</option>
                               <option value="nodejs">Node.js</option>
                               <option value="golang">Go</option>
                           </select>
                       </div>

                       <div class="form-group">
                           <label>Database Configuration</label>
                           <select class="form-control">
                               <option value="single">Single Table Design</option>
                               <option value="multi">Multiple Tables</option>
                           </select>
                       </div>

                       <div style="display: flex; gap: 8px; justify-content: flex-end;">
                           <button type="button" class="step-action" style="background: #94a3b8" onclick="hideNewAppModal()">Cancel</button>
                           <button type="submit" class="step-action">Create Application</button>
                       </div>
                   </form>
               </div>
           </div>
       </main>
    </div>
   <script>
       function showNewAppModal() {
           document.getElementById('newAppModal').classList.add('show');
       }

       function hideNewAppModal() {
           document.getElementById('newAppModal').classList.remove('show');
       }
   </script>
</body>
</html>
      HTML
    }
  }
}
