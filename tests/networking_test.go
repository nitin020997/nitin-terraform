package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// Terratest — runs real Terraform against LocalStack and validates outputs
// Run: go test ./tests/ -v -timeout 10m

func TestAwsNetworkingModule(t *testing.T) {
	t.Parallel()

	opts := &terraform.Options{
		TerraformDir: "../modules/aws/networking",
		Vars: map[string]interface{}{
			"environment":          "dev",
			"vpc_cidr":             "10.99.0.0/16",
			"availability_zones":   []string{"us-east-1a", "us-east-1b"},
			"public_subnet_cidrs":  []string{"10.99.1.0/24", "10.99.2.0/24"},
			"private_subnet_cidrs": []string{"10.99.10.0/24", "10.99.11.0/24"},
			"enable_nat_gateway":   true,
			"single_nat_gateway":   true,
		},
		EnvVars: map[string]string{
			"AWS_ACCESS_KEY_ID":     "test",
			"AWS_SECRET_ACCESS_KEY": "test",
			"AWS_DEFAULT_REGION":    "us-east-1",
		},
	}

	defer terraform.Destroy(t, opts)
	terraform.InitAndApply(t, opts)

	vpcID := terraform.Output(t, opts, "vpc_id")
	assert.NotEmpty(t, vpcID, "VPC ID should not be empty")

	publicSubnets := terraform.OutputList(t, opts, "public_subnet_ids")
	assert.Len(t, publicSubnets, 2, "Should have 2 public subnets")

	privateSubnets := terraform.OutputList(t, opts, "private_subnet_ids")
	assert.Len(t, privateSubnets, 2, "Should have 2 private subnets")

	natGateways := terraform.OutputList(t, opts, "nat_gateway_ids")
	assert.Len(t, natGateways, 1, "single_nat_gateway=true should create exactly 1 NAT gateway")
}

func TestAwsNetworkingValidation(t *testing.T) {
	t.Parallel()

	// Test that invalid environment is rejected at plan time
	opts := &terraform.Options{
		TerraformDir: "../modules/aws/networking",
		Vars: map[string]interface{}{
			"environment":          "invalid-env",
			"availability_zones":   []string{"us-east-1a"},
			"public_subnet_cidrs":  []string{"10.0.1.0/24"},
			"private_subnet_cidrs": []string{"10.0.10.0/24"},
		},
	}

	_, err := terraform.InitAndPlanE(t, opts)
	assert.Error(t, err, "Invalid environment should fail validation")
}
