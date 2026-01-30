# Cleanup Script for Orphaned Nexus-SUS Resources
# WARNING: This script deletes specific resources hardcoded below. Use with caution.

$ErrorActionPreference = "Continue" # Continue verifies subsequent resources even if one fails

function Write-Header {
    param($Text)
    Write-Host "`n==================================================" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
}

function Delete-ECR-Repo {
    param($RepoName)
    Write-Host "Checking ECR Repository: $RepoName..." -NoNewline
    $exists = aws ecr describe-repositories --repository-names $RepoName --region us-east-1 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host " FOUND!" -ForegroundColor Red
        aws ecr delete-repository --repository-name $RepoName --region us-east-1 --force
        Write-Host "Deleted $RepoName." -ForegroundColor Green
    } else {
        Write-Host " Not found." -ForegroundColor Gray
    }
}

function Delete-RDS-Subnet-Group {
    param($Name)
    Write-Host "Checking DB Subnet Group: $Name..." -NoNewline
    $exists = aws rds describe-db-subnet-groups --db-subnet-group-name $Name --region us-east-1 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host " FOUND!" -ForegroundColor Red
        aws rds delete-db-subnet-group --db-subnet-group-name $Name --region us-east-1
        Write-Host "Deleted $Name." -ForegroundColor Green
    } else {
        Write-Host " Not found." -ForegroundColor Gray
    }
}

function Delete-RDS-Param-Group {
    param($Name)
    Write-Host "Checking DB Parameter Group: $Name..." -NoNewline
    $exists = aws rds describe-db-parameter-groups --db-parameter-group-name $Name --region us-east-1 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host " FOUND!" -ForegroundColor Red
        aws rds delete-db-parameter-group --db-parameter-group-name $Name --region us-east-1
        Write-Host "Deleted $Name." -ForegroundColor Green
    } else {
        Write-Host " Not found." -ForegroundColor Gray
    }
}

function Delete-S3-Bucket {
    param($BucketName)
    Write-Host "Checking S3 Bucket: $BucketName..." -NoNewline
    $exists = aws s3api head-bucket --bucket $BucketName --region us-east-1 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host " FOUND!" -ForegroundColor Red
        Write-Host "Deleting objects in $BucketName..."
        aws s3 rm s3://$BucketName --recursive --region us-east-1
        aws s3 rb s3://$BucketName --region us-east-1
        Write-Host "Deleted $BucketName." -ForegroundColor Green
    } else {
        Write-Host " Not found." -ForegroundColor Gray
    }
}

function Delete-IAM-Role {
    param($RoleName)
    Write-Host "Checking IAM Role: $RoleName..." -NoNewline
    $exists = aws iam get-role --role-name $RoleName 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host " FOUND!" -ForegroundColor Red
        
        # Detach policies first
        Write-Host "  Detaching policies..."
        $policies = aws iam list-attached-role-policies --role-name $RoleName --query 'AttachedPolicies[*].PolicyArn' --output text
        if ($policies) {
            $policies.Split("`t") | ForEach-Object {
                if ($_) {
                    $policyArn = $_.Trim()
                    if ($policyArn) {
                         aws iam detach-role-policy --role-name $RoleName --policy-arn $policyArn
                    }
                }
            }
        }
        
        aws iam delete-role --role-name $RoleName
        Write-Host "Deleted $RoleName." -ForegroundColor Green
    } else {
        Write-Host " Not found." -ForegroundColor Gray
    }
}

Write-Header "STARTING CLEANUP OF ORPHANED RESOURCES"

# 1. ECR Repos
$ecrRepos = @("nexus-sus-etl", "nexus-sus-frontend", "nexus-sus-engine", "nexus-sus-api")
foreach ($repo in $ecrRepos) { Delete-ECR-Repo -RepoName $repo }

# 2. RDS
Delete-RDS-Subnet-Group -Name "nexus-sus-db-subnet-group"
Delete-RDS-Param-Group -Name "nexus-sus-postgres-params"

# 3. S3
Delete-S3-Bucket -BucketName "nexus-sus-data-lake"

# 4. IAM
Delete-IAM-Role -RoleName "nexus-sus-etl-role"

Write-Header "CLEANUP COMPLETE"
Write-Host "Resources without environment suffixes have been removed."
Write-Host "You can now run 'terraform apply' safely." -ForegroundColor Green
