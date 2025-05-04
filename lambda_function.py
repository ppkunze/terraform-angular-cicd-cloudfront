import os
import boto3
import json

def lambda_handler(event, context):
    client = boto3.client('cloudfront')
    distribution_id = os.environ['DISTRIBUTION_ID']
    
    # Check if this is a CodePipeline invocation
    job_id = None
    if 'CodePipeline.job' in event:
        job_id = event['CodePipeline.job']['id']
        print(f"CodePipeline job ID: {job_id}")
    
    try:
        # Create the invalidation
        response = client.create_invalidation(
            DistributionId=distribution_id,
            InvalidationBatch={
                'Paths': {'Quantity': 1, 'Items': ['/*']},
                'CallerReference': str(context.aws_request_id)
            }
        )
        
        invalidation_id = response['Invalidation']['Id']
        print(f"Invalidation {invalidation_id} submitted successfully - it will process in the background")
        
        # If this was called from CodePipeline, put success result immediately
        if job_id:
            codepipeline = boto3.client('codepipeline')
            codepipeline.put_job_success_result(jobId=job_id)
            print(f"Successfully notified CodePipeline of job completion: {job_id}")
        
        return {
            "status": "Succeeded",
            "invalidation_id": invalidation_id,
            "message": "CloudFront invalidation submitted successfully"
        }
    
    except Exception as e:
        error_message = f"Error invalidating CloudFront distribution: {str(e)}"
        print(error_message)
        
        # If this was called from CodePipeline, report the failure
        if job_id:
            try:
                codepipeline = boto3.client('codepipeline')
                codepipeline.put_job_failure_result(
                    jobId=job_id,
                    failureDetails={
                        'type': 'JobFailed',
                        'message': error_message
                    }
                )
                print(f"Reported failure to CodePipeline for job: {job_id}")
            except Exception as pipeline_error:
                print(f"Failed to report to CodePipeline: {str(pipeline_error)}")
        
        # Re-raise the exception for Lambda error handling
        raise
