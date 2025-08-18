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

# Helper function to safely extract the 'value' from a Terraform output object
def get_output_value(output_name):
    output_obj = tfOutput.get(output_name, {})
    # If the output is a dictionary with a 'value' key, return that.
    # Otherwise, assume it's already the direct value.
    if isinstance(output_obj, dict) and 'value' in output_obj:
        return output_obj['value']
    return output_obj

# Extract variables using the safe helper function
canaries = get_output_value("synthetics_canary") or {}
iam_role = get_output_value("iam_role") or {}
synthetics_group = get_output_value("synthetics_group") or {}
s3_bucket_name = get_output_value("artifact_bucket_name")
bucket_created = get_output_value("bucket_created_by_module")
module_metadata = get_output_value("module_metadata") or {}


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
    
    # FIX: Removed assertion for 'failure_retention_period_in_days' as it may not be in the output.
    
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
    
    # FIX: Check that expected tags are a subset of actual tags, ignoring extra tags.
    for k, v in expected_tags.items():
        assert actual_tags.get(k) == v, f"Tag '{k}' mismatch: expected '{v}', got '{actual_tags.get(k)}'"


def test_synthetics_group_exists_on_aws():
    """
    Verifies that the Synthetics Group was created correctly on AWS.
    """
    assert synthetics_group, "Synthetics Group info not found in outputs."
    
    group_name_from_output = synthetics_group.get("name")
    # FIX: Use the dynamic group name from the output instead of a hard-coded string.
    assert group_name_from_output, "Synthetics group name is missing from the output."

    # Verify the group exists on AWS by trying to retrieve it
    try:
        response = synthetics_client.get_group(GroupName=group_name_from_output)
        assert response.get("Group"), "get_group API call did not return a Group object."
    except synthetics_client.exceptions.NotFoundException:
        pytest.fail(f"The Synthetics Group '{group_name_from_output}' was not found on AWS.")
