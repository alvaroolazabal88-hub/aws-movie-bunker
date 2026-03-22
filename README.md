
# 🎬 AWS Cloud Movie Bunker (S3 + OAC + CloudFront)

A secure, high-performance media delivery solution deployed via **Infrastructure as Code (Terraform)**. This project serves private video content through Amazon CloudFront, ensuring the S3 "Bunker" remains completely inaccessible to the public.

## 🏗️ Architecture Overview
* **Storage**: Amazon S3 (Public Access Blocked).
* **CDN**: Amazon CloudFront for global edge delivery.
* **Security**: Origin Access Control (OAC) with SigV4 signing.
* **Encryption**: AES-256 at rest and TLS 1.2+ (HTTPS) in transit.

## 🚀 Troubleshooting & Lessons Learned

During the development phase, several technical hurdles were cleared:

1.  **Terraform Syntax Scoping**: Initial deployment failed due to unterminated string literals and unclosed output blocks. 
    * *Solution*: Implemented `terraform validate` as a mandatory pre-flight check.
2.  **Path Resolution**: Using absolute paths (`/Users/...`) was necessary for local file uploads to ensure the Terraform runner could locate the `/movies` directory and the `index.html` frontend.
3.  **MIME Type Enforcement**: S3 defaults to `binary/octet-stream` for unknown files.
    * *Solution*: Manually mapped `content_type` in the `aws_s3_object` resource to ensure browsers render HTML and play MP4 files instead of downloading them as raw data.

## 💰 Cost Analysis (Monthly Estimate)
This architecture is highly optimized for the **AWS Free Tier**:

| Service | Cost Driver | Estimate |
| :--- | :--- | :--- |
| **Amazon S3** | Storage (Standard) | ~$0.023 / GB |
| **CloudFront** | Data Transfer Out (DTO) | 1 TB/mo Free Tier |
| **ACM** | SSL/TLS Certificates | $0.00 (Free) |
| **CloudFront** | HTTP/HTTPS Requests | 10M requests/mo Free |

**Pro-Tip**: Leveraging **CloudFront Caching** significantly reduces costs by minimizing GET requests to the S3 origin.

## 🛠️ Deployment Instructions
1. Clone the repository.
2. Ensure your `.mp4` files are located in the `/movies` directory.
3. Run the following commands:
   ```bash
   terraform init
   terraform apply