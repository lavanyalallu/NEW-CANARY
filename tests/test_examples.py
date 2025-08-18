import json
import boto3
from botocore.config import Config

def getOutputs():
    out = {}
    with open("examples/outputs.json", "r") as f:
        raw = json.load(f)
    for o in raw:
        out[o] = raw[o]
    return out

def getMetadata():
    with open("metadata.json", "r") as f:
        data = json.load(f)
    return data

# Resources
metadata = getMetadata()
tfOutput = getOutputs()

def test_empty():
    assert True
#####

# --- Boto3 Clients and Resource Extraction ---
# It's better practice to initialize clients once
cfg = Config(region_name="us-east-1") # Assuming us-east-1, adjust if needed
synthetics_client = boto3.client('synthetics', config=cfg)
iam_client = boto3.client('iam', config=cfg)
s3_client = boto3.client('s3', config=cfg)

# Extract the actual 'value' from the Terraform output objects
canaries = tfOutput.get("synthetics_canary", {}).get("value", {})
iam_role = tfOutput.get("iam_role", {}).get("value", {})
synthetics_group = tfOutput.get("synthetics_group", {}).get("value", {})
s3_bucket_name = tfOutput.get("artifact_bucket_name", {}).get("value")
bucket_created = tfOutput.get("bucket_created_by_module", {}).get("value")
module_metadata = tfOutput.get("module_metadata", {}).get("value", {})


# --- Canary Test Cases ---

def test_google_canary_configuration():
    """
    Validates the configuration for the 'test-google' canary.
    """
    canary_name = "test-google"
    assert canary_name in canaries, f"Canary '{canary_name}' not found in Terraform outputs."
    
    canary_details = canaries[canary_name]
    
    # Test values from the output file
    assert canary_details["name"] == canary_name
    assert canary_details["handler"] == "pageLoadBlueprint.handler"
    assert canary_details["failure_retention_period_in_days"] == 14
    
    # Test the ARN
    arn = canary_details.get("arn")
    assert arn, "ARN is missing for test-google canary."
    assert arn.startswith("arn:aws:synthetics:")
    assert f":canary:{canary_name}" in arn

    # Test the run configuration
    run_config = canary_details.get("run_config", [{}])[0]
    assert run_config.get("timeout_in_seconds") == 90


# --- Shared Resource Test Cases ---

def test_s3_artifact_bucket():
    """
    Verifies the S3 artifact bucket exists and has the correct tags.
    This test assumes the bucket is always created by the module for this example.
    """
    assert s3_bucket_name, "S3 artifact bucket name not found in Terraform outputs."
    assert bucket_created is True, "Expected the module to create the S3 bucket, but it did not."

    # 1. Verify the bucket exists on AWS and is accessible
    try:
        s3_client.head_bucket(Bucket=s3_bucket_name)
    except s3_client.exceptions.ClientError as e:
        pytest.fail(f"S3 artifact bucket '{s3_bucket_name}' does not exist or is not accessible: {e}")

    # 2. Verify the bucket's tags match the module's input tags
    expected_tags = module_metadata.get("tags", {})
    assert expected_tags, "Expected tags not found in module_metadata output."

    response = s3_client.get_bucket_tagging(Bucket=s3_bucket_name)
    actual_tags = {tag['Key']: tag['Value'] for tag in response.get('TagSet', [])}
    
    assert actual_tags == expected_tags, "S3 bucket tags do not match the expected tags."


def test_synthetics_group_exists_on_aws():
    """
    Verifies that the Synthetics Group was created correctly on AWS.
    """
    assert synthetics_group, "Synthetics Group info not found in outputs."
    
    group_name_from_output = synthetics_group.get("name")
    assert group_name_from_output == "example-website-monitors"

    # Verify the group exists on AWS by trying to retrieve it
    try:
        response = synthetics_client.get_group(GroupName=group_name_from_output)
        assert response.get("Group"), "get_group API call did not return a Group object."
    except synthetics_client.exceptions.NotFoundException:
        pytest.fail(f"The Synthetics Group '{group_name_from_output}' was not found on AWS.")
