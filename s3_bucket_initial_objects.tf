
resource "aws_s3_object" "html_pages" {
  for_each = local.html_pages

  bucket       = aws_s3_bucket.website.id
  key          = each.key
  content_type = "text/html"
  content      = each.value.content
}

# Error pages
resource "aws_s3_object" "error_pages" {
  for_each = local.error_pages

  bucket       = aws_s3_bucket.website.id
  key          = each.key
  content_type = "text/html"

  content = <<EOF
<!DOCTYPE html>
<html lang="en" style="height: 100%; margin: 0; padding: 0;">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${each.value.title} - ${var.domain_name}</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
    <style>
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
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

        h1 {
            font-size: clamp(2rem, 5vw, 3.5rem);
            margin-bottom: 1rem;
            text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3);
        }

        p {
            font-size: clamp(1rem, 2vw, 1.25rem);
            opacity: 0.9;
        }

        .back-link {
            margin-top: 2rem;
            color: white;
            text-decoration: none;
            font-size: 1.1rem;
            padding: 0.5rem 1rem;
            border: 2px solid white;
            border-radius: 4px;
            transition: all 0.3s ease;
        }

        .back-link:hover {
            background: rgba(255, 255, 255, 0.1);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>${each.value.title}</h1>
        <p>${each.value.message}</p>
        <a href="/" class="back-link">Back to Homepage</a>
    </div>
</body>
</html>
EOF

  lifecycle {
    ignore_changes = [
      etag,
      content_type,
      content,
      content_base64,
      metadata
    ]
  }

  tags = var.tags
}
