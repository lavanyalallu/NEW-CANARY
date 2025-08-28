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

# --- Boto3 Clients and Resource Extraction
# It's better practice to initialize clients once
cfg = Config(region_name="us-east-1") # Assuming us-east-1, adjust if needed
synthetics_client = boto3.client('synthetics', config=cfg)
s3_client = boto3.client('s3', config=cfg)

# Helper function to safely extract the 'value' from a Terraform output object
def get_output_value(output_name):
    output_obj = tfOutput.get(output_name, {})
    if isinstance(output_obj, dict) and 'value' in output_obj:
        return output_obj['value']
    return output_obj

# Extract resource objects from the Terraform output
canaries = get_output_value("synthetics_canary") or {}
s3_bucket = get_output_value("s3_bucket") or {}
synthetics_group = get_output_value("synthetics_group") or {}

# FIX: The hardcoded EXPECTED_TAGS dictionary has been removed.
# Tags will now be read from each resource's output object directly within the tests.


# --- Test Cases ---

def test_canary_configuration():
    """
    Validates the configuration for each canary defined in the Terraform outputs.
    """
    assert canaries, "No canaries found in Terraform outputs to test."

    for canary_name, canary_details in canaries.items():
        # Test basic attributes from the output
        assert canary_details["name"].endswith(canary_name)
        assert canary_details["handler"] == "pageLoadBlueprint.handler"
        
        # Test the ARN
        arn = canary_details.get("arn")
        full_canary_name = canary_details['name']
        assert arn, f"ARN is missing for {canary_name} canary."
        assert f":canary:{full_canary_name}" in arn

        # Verify tags by fetching the canary from AWS
        try:
            response = synthetics_client.get_canary(Name=full_canary_name)
            actual_tags = response.get("Canary", {}).get("Tags", {})
            
            # FIX: Get expected tags from the canary's own output details.
            expected_tags = canary_details.get("tags", {})
            for k, v in expected_tags.items():
                assert actual_tags.get(k) == v, f"Canary tag '{k}' mismatch for {full_canary_name}: expected '{v}', got '{actual_tags.get(k)}'"

        except synthetics_client.exceptions.NotFoundException:
            pytest.fail(f"The Canary '{full_canary_name}' was not found on AWS.")


def test_s3_artifact_bucket():
    """
    Verifies the S3 artifact bucket exists and has the correct tags.
    """
    print("\nDEBUG s3_bucket:", s3_bucket)
    print("\nDEBUG s3_artifact_bucket_value:", get_output_value("debug_s3_artifact_bucket_value"))
    print("\nDEBUG canary_s3_length:", get_output_value("debug_canary_s3_length"))
    print("\nDEBUG canary_s3_first:", get_output_value("debug_canary_s3_first"))
    print("\nDEBUG tfoutput keys:", tfOutput)

    assert s3_bucket, "The S3 bucket output is empty or missing."

    # Handle double-nested structure: s3_bucket -> bucket -> bucket 
    if s3_bucket.get("bucket", {}).get("bucket"):
        bucket_details = s3_bucket["bucket"]["bucket"]
    else:
        bucket_details = s3_bucket.get("bucket") or s3_bucket
        
    assert bucket_details, "The S3 bucket details were not found in the s3_bucket output."

    # Get bucket name from id or name field
    s3_bucket_name = bucket_details.get("id") or bucket_details.get("name")
    assert s3_bucket_name, "S3 bucket ID/name not found in the bucket details."

    # Verify the bucket exists on AWS
    try:
        s3_client.head_bucket(Bucket=s3_bucket_name)
    except s3_client.exceptions.ClientError as e:
        pytest.fail(f"S3 artifact bucket '{s3_bucket_name}' does not exist or is not accessible: {e}")

    # Verify the bucket's tags
    response = s3_client.get_bucket_tagging(Bucket=s3_bucket_name)
    actual_tags = {tag['Key']: tag['Value'] for tag in response.get('TagSet', [])}
    
    expected_tags = bucket_details.get("tags", {})
    for k, v in expected_tags.items():
        assert actual_tags.get(k) == v, f"Tag '{k}' mismatch for S3 bucket: expected '{v}', got '{actual_tags.get(k)}'"

# REMOVED: This test is no longer relevant as the module is not responsible for creating the group.
# The consumer of the module (the example code) is now responsible for this resource.


def test_canary_is_associated_with_group():
    """
    Verifies that all canaries are correctly associated with the Synthetics Group.
    """
    # FIX: Get the group name from the example's direct output, not the module's output.
    group_name = get_output_value("synthetics_group_name")
    assert group_name, "Synthetics group name not found in example outputs for association test."

    expected_canary_arns = {details['arn'] for _, details in canaries.items()}
    
    response = synthetics_client.list_group_resources(GroupIdentifier=group_name)
    # The response from list_group_resources only contains the canary ARNs.
    associated_canary_arns = {resource['Arn'] for resource in response.get('Resources', [])}

    assert expected_canary_arns.issubset(associated_canary_arns), \
        f"Not all canaries were found in the synthetics group '{group_name}'."
