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

# FIX: The parametrize decorator is removed. The test now loops internally.
def test_canary_configuration():
    """
    Validates the configuration for each canary defined in the Terraform outputs.
    """
    assert canaries, "No canaries found in the Terraform outputs to test."

    # Loop through each canary from the output file
    for canary_name, canary_details in canaries.items():
        # Test values from the output file
        assert canary_details["name"] == canary_name
        assert canary_details["handler"] == "pageLoadBlueprint.handler"
        
        # Test the ARN
        arn = canary_details.get("arn")
        assert arn, f"ARN is missing for {canary_name} canary."
        assert arn.startswith("arn:aws:synthetics:")
        assert f":canary:{canary_name}" in arn

        # Test the run configuration
        run_config = canary_details.get("run_config", [{}])[0]
        assert run_config.get("timeout_in_seconds") == 90

        # Verify tags by fetching the canary from AWS
        try:
            response = synthetics_client.get_canary(Name=canary_name)
            actual_tags = response.get("Canary", {}).get("Tags", {})
            
            expected_tags = module_metadata.get("tags", {})
            assert expected_tags, "Expected tags not found in module_metadata output."

            for k, v in expected_tags.items():
                assert actual_tags.get(k) == v, f"Canary tag '{k}' mismatch for {canary_name}: expected '{v}', got '{actual_tags.get(k)}'"

        except synthetics_client.exceptions.NotFoundException:
            pytest.fail(f"The Canary '{canary_name}' was not found on AWS.")


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
    assert group_name_from_output, "Synthetics group name is missing from the output."

    # Verify the group exists on AWS by trying to retrieve it
    try:
        response = synthetics_client.get_group(GroupIdentifier=group_name_from_output)
        group_details = response.get("Group")
        assert group_details, "get_group API call did not return a Group object."

        # Verify the tags on the group
        actual_tags = group_details.get("Tags", {})
        expected_tags = module_metadata.get("tags", {})
        assert expected_tags, "Expected tags not found in module_metadata output."

        for k, v in expected_tags.items():
            assert actual_tags.get(k) == v, f"Group tag '{k}' mismatch: expected '{v}', got '{actual_tags.get(k)}'"

    except synthetics_client.exceptions.NotFoundException:
        pytest.fail(f"The Synthetics Group '{group_name_from_output}' was not found on AWS.")


def test_canary_is_associated_with_group():
    """
    Verifies that all canaries are correctly associated with the Synthetics Group.
    """
    # Skip this test if the group wasn't created, to avoid unnecessary failures.
    if not synthetics_group:
        pytest.skip("Skipping group association test; group was not created.")

    group_name = synthetics_group.get("name")
    assert group_name, "Synthetics group name is missing from the output."

    # FIX: Get all expected canary ARNs from the Terraform output, not just one.
    expected_canary_arns = {details['arn'] for name, details in canaries.items() if 'arn' in details}
    assert expected_canary_arns, "No canary ARNs found in the outputs to test for group association."

    # Get all resources associated with the group from AWS
    response = synthetics_client.list_group_resources(GroupIdentifier=group_name)
    associated_canary_arns = set(response.get('Resources', []))

    # FIX: Check that the set of expected ARNs is a subset of the actual associated ARNs.
    # This ensures every canary we created is in the group.
    assert expected_canary_arns.issubset(associated_canary_arns), \
        f"Not all canaries were found in the synthetics group '{group_name}'."
