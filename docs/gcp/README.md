# Google Cloud Platform Deployments

## Table of Contents
- [Google Cloud Platform Deployments](#google-cloud-platform-deployments)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [GCP Quickstart Tutorial](#gcp-quickstart-tutorial)
  - [Manual Terraform Configuration](#manual-terraform-configuration)
    - [Requirements](#requirements)
    - [Selecting a Deployment](#selecting-a-deployment)
    - [GCP Setup](#gcp-setup)
    - [CAS Manager as a Service Setup](#cas-manager-as-a-service-setup)
    - [Customizing terraform.tfvars](#customizing-terraformtfvars)
      - [Workstation IdleShutDown](#workstation-idleshutdown)
    - [(Optional) Encrypting Secrets](#optional-encrypting-secrets)
      - [Encryption Using Python Script](#encryption-using-python-script)
      - [Manual Encryption](#manual-encryption)
    - [Creating the deployment](#creating-the-deployment)
    - [Add Workstations in CAS Manager](#add-workstations-in-cas-manager)
    - [Start PCoIP Session](#start-pcoip-session)
    - [Changing the deployment](#changing-the-deployment)
    - [Deleting the deployment](#deleting-the-deployment)
  - [Troubleshooting](#troubleshooting)

---

## Introduction

There are two ways to create a Cloud Access Software (CAS) deployment using this repository:
- [__GCP Quickstart Tutorial__](#gcp-quickstart-tutorial): for those who have less experience with the Command Line Interface (CLI) and Terraform, use this tutorial to get a deployment running with the least amount of effort by using the [Google Cloud Shell](https://cloud.google.com/shell). The quickstart will prepare most of the requirements for the user and call a script to deploy the _single-connector_ deployment using Terraform.
- [__Manual Terraform Configuration__](#manual-terraform-configuration): for those who are experienced with the CLI and Terraform, this is the primary way this repository is meant to be used. A user can choose between different types of deployments, variables can be customized, and deployment architecture can be modified to suit the user's needs.

## GCP Quickstart Tutorial

The quickest way to create a reference deployment on GCP is to run the Quickstart Python script in the Google Cloud Shell. The goal is to automate the creation of a [single-connector deployment](#single-connector) as much as possible by using auto-generated values for required parameters.

Click on the button below to clone this repository in your GCP Cloud Shell and launch the tutorial. The tutorial can be found on the panel to the right once the GCP Cloud Shell opens. [This video](https://www.youtube.com/watch?v=lN2GesgvLKA) is also available to guide the viewer through the GCP Quickstart deployment process.

[![Open in Google Cloud Shell](http://gstatic.com/cloudssh/images/open-btn.png)](https://console.cloud.google.com/cloudshell/open?git_repo=https://github.com/teradici/cloud_deployment_scripts&tutorial=quickstart/gcp/tutorial.md&show=terminal)

## Manual Terraform Configuration

Before starting, consider watching [this video](https://www.youtube.com/watch?v=ESzon04cW4Y) on how to use this repo to deploy a single-connector deployment on GCP from a Linux environment. The video guides the viewer through the entire deployment process from set up to tear down. It also shows how the deployment can be managed through CAS Manager as a Service (CAS-MS) and how end-users can connect to their machines using a PCoIP client. While the video shows the single-connector deployment, the process of creating other deployments is very similar. For deployment from a Windows environment, please see the relevant portions of our [AWS video](https://www.youtube.com/watch?v=hwEOoG4pmMQ). Note that since this repository is constantly being updated, there might be minor differences between what is shown in the video compared to the latest version on GitHub.

### Requirements
- the user must have owner permissions to a GCP project
- ensure there is sufficient quota in the GCP project for the chosen number of workstations. Please check the quota here: https://console.cloud.google.com/iam-admin/quotas
- ensure that the GPU virtual workstation for the graphics machines are available in the specified region and zone. Please check the availability here: https://cloud.google.com/compute/docs/gpus/gpu-regions-zones
- a PCoIP Registration Code is needed. Contact Teradici sales or purchase subscription here: https://www.teradici.com/compare-plans
- for deployments using CAS Manager as a Service, a CAS Manager Deployment Service Account is needed. Please see the [CAS Manager as a Service Setup](#cas-manager-as-a-service-setup) section below.
- an SSH private / public key pair is required for Terraform to log into Linux hosts. Please visit [ssh-key-pair-setup](/docs/ssh-key-pair-setup.md) for instructions.
- if custom SSL key and certificates are required, the SSL key and certificate files are needed in PEM format.
- Terraform v1.0 or higher must be installed. Please download Terraform from https://www.terraform.io/downloads.html

### Selecting a Deployment
This repository contains Terraform configurations for a number of different CAS deployment types. Please see the the [Deployments](deployments.md) page for a more detailed description of the various deployments.

### GCP Setup
Although it is possible to create deployments in existing and currently in-use GCP projects, it is recommended to create them in new projects to reduce chances of name collisions and interfering with operations of existing resources.

With a new GCP project:
- create a new service account with __Editor__ and __Cloud KMS CryptoKey Encrypter/Decrypter__ permissions. Create and download the credentials in JSON format. These credentials are needed by CAS Manager to manage the deployment, such as creating workstations, monitoring workstation statuses, and providing power management features.  The credentials are also needed by the Terraform configuration to create the initial deployment.
- enable the following APIs in the GCP console or via the command `gcloud services enable deploymentmanager.googleapis.com cloudkms.googleapis.com cloudresourcemanager.googleapis.com compute.googleapis.com dns.googleapis.com`:
    - Cloud Deployment Manager V2
    - Cloud Key Management Service (KMS)
    - Cloud Resource Manager
    - Compute Engine
    - Google Cloud DNS
- (Optional) For better security, create a Google KMS key ring and crypto key to encrypt secrets. Please refer to https://cloud.google.com/kms/docs/creating-keys for instructions to create keys.

### CAS Manager as a Service Setup

(for deployments using the CAS Manager as a Service only)

Follow the steps below to set up a CAS Manager deployment and download CAS Manager Deployment Service Acccount credentials. For deployments using CAS Manager running in a virtual machine, these steps can be skipped because the Terraform configuration will automatically set those up for the user.

1. Login to CAS Manager Admin Console at https://cas.teradici.com using a Google Workspace, Google Cloud Identity, or Microsoft business account.
2. Create a new deployment with your PCoIP registration code.
4. Select `Edit deployment`, select the `CLOUD SERVICE ACCOUNTS` tab, and follow the instructions to add your GCP account.
5. Select `Edit deployment`, select the `DEPLOYMENT SERVICE ACCOUNTS` tab, click on the + icon to create a CAS Manager Deployment Service Account.
6. Click on `DOWNLOAD JSON FILE` to download the CAS Manager Deployment Service Account credentials file, which will be used in `terraform.tfvars`.

### Customizing terraform.tfvars
`terraform.tfvars` is the file in which a user specify variables for a deployment. In each deployment, there is a `terraform.tfvars.sample` file showing the required variables that a user must provide, along with other commonly used but optional variables. Uncommented lines show required variables, while commented lines (those beginning with `#`) show optional variables with their default or sample values. A complete list of available variables are described in the variable definition file `vars.tf` of the deployment.

Path variables in `terraform.tfvars` must be absolute and are dependent on the host platform:
- on Linux systems, the forward slash / is used as the path segment separator. `gcp_credentials_file = "/path/to/cred.json"`
- on Windows systems, the default Windows backslash \ separator must be changed to forward slash as the path segment separator. `gcp_credentials_file = "C:/path/to/cred.json"`

Save `terraform.tfvars.sample` as `terraform.tfvars` in the same directory, and fill out the required and optional variables.

#### Workstation IdleShutDown
Workstations created by Terraform have IdleShutDown Agent enabled by default so that the remote workstation will shutdown when it is idle. The default settings can be changed by specifying the `idle_shutdown_enable` (default: `true`), `idle_shutdown_minutes_idle_before_shutdown` (default: `240`), and `idle_shutdown_polling_interval_minutes` (default: `15`) variables in `terraform.tfvars`. Learn more about IdleShutDown [here](https://www.teradici.com/web-help/cas_manager_as_a_service/reference/install_configure_cam_idle_shutdown/).

### (Optional) Encrypting Secrets
`terraform.tfvars` variables include sensitive information such as Active Directory passwords, PCoIP registration key and the CAS Manager Deployment Service Account credentials file. These secrets are stored in the local files `terraform.tfvars` and `terraform.tfstate`, and will also be uploaded as part of provisioning scripts to a Google Cloud Storage bucket.

To enhance security, the Terraform configurations are designed to support both plaintext and KMS-encrypted secrets. Plaintext secrets requires no extra steps, but will be stored in plaintext in the above mentioned locations. It is recommended to encrypt the secrets in `terraform.tfvars` before deploying. Secrets can be encrypted manually first before being entered into `terraform.tfvars`, or they can be encrypted using a Python script located under the tools directory.

#### Encryption Using Python Script
The easiest way to encrypt secrets is to use the kms_secrets_encryption.py Python script under the tools/ directory, which automates the KMS encryption process. 
1. First, fill in all the variables in `terraform.tfvars`, including any sensitive information.
2. Ensure the `kms_cryptokey_id` variable in `terraform.tfvars` is commented out, as this script will attempt to create the crypto key used to encrypt the secrets:
   ```
   # kms_cryptokey_id = "projects/<project-id>/locations/<location>/keyRings/<keyring-name>/cryptoKeys/<key-name>"
   ```
3. Run the following command inside the tools directory:
   ```
   ./kms_secrets_encryption.py </path/to/terraform.tfvars>
   ```

The script will replace all the plaintext secrets in `terraform.tfvars` with ciphertext. Any text files specified under the secrets section as a path will also be encrypted. 

The script can also reverse the encryption by executing it with the '-d' flag. See script's documentation for details (--help).

#### Manual Encryption
Alernatively, the secrets can be manually encrypted. To encrypt secrets using the Google KMS crypto key created in the 'GCP Setup' section above, refer to https://cloud.google.com/kms/docs/encrypt-decrypt. Note that ciphertext must be base64 encoded before being used in `terraform.tfvars`.

1. create a KMS key ring and crypto key. Please refer to https://cloud.google.com/kms/docs/creating-keys for instructions to create keys.
2. in `terraform.tfvars`, ensure that the `kms_cryptokey_id` variable is uncommented and is set to the resource path of the KMS key used to encrypt the secrets:
   ```
   kms_cryptokey_id = "projects/<project-id>/locations/<location>/keyRings/<keyring-name>/cryptoKeys/<key-name>"
   ```
3. run the following command in GCP Cloud Shell or a Linux shell with gcloud installed to encrypt a plaintext secret:
   ```
   echo -n <secret> | gcloud kms encrypt --location <location> --keyring <keyring_name> --key <key_name> --plaintext-file - --ciphertext-file - | base64
   ```
   Encrypt and replace the values of the variables in the secrets section in `terraform.tfvars` with the ciphertext generated. For example, `<ciphertext>` below should be replaced with the actual ciphertext generated - do not include < and >.
   ```
   dc_admin_password           = "<ciphertext>"
   safe_mode_admin_password    = "<ciphertext>"
   ad_service_account_password = "<ciphertext>"
   pcoip_registration_code     = "<ciphertext>"
   ```
4. run the following command in GCP Cloud Shell or a Linux shell with gcloud installed to encrypt the CAS Manager Deployment Service Account JSON credentials file:
   ```
   gcloud kms encrypt --location <location> --keyring <keyring-name> --key <key-name> --plaintext-file </path/to/cas-manager-service-account.json> --ciphertext-file </path/to/cas-manager-service-account.json.encrypted>"
   ```
   Replace the value of the `cas_manager_deployment_sa_file` variable in `terraform.tfvars` with the absolute path to the encrypted file generated.
   ```
   cas_manager_deployment_sa_file = "/path/to/cas-manager-service-account.json.encrypted"
   ```

### Creating the deployment
With `terraform.tfvars` customized:

1. run `terraform init` to initialize the deployment
2. run `terraform apply` to display the resources that will be created by Terraform
3. answer `yes` to start creating the deployment

A typical deployment should take 15 to 30 minutes. When finished, Terraform will display a number of values of interest, such as the load balancer IP address. At the end of the deployment, the resources may still take a few minutes to start up completely. Cloud Access Connectors (CACs) should register themselves with CAS Manager and show up in the Admin Console in CAS Manager.

**Security Note**: The Domain Controller has been assigned a public IP address by default, so that Terraform can show the progress of setting up the Domain Controller. Access to this public IP address is limited by GCP firewall to the IP address of the Terraform host and any IP addresses specified in the `allowed_admin_cidrs` variable in `terraform.tfvars`. It is recommended that this public IP address be removed from the Domain Controller (see [here](https://cloud.google.com/compute/docs/ip-addresses/reserve-static-external-ip-address#IP_assign)) unless there is a specific need for access from public IP addresses. Also note that NAT will need to be set up when the public IP is removed to provide Internet access to the Domain Controller.     

**Note**: If Terraform returns the error "An argument named `sensitive` is not expected here." this means that the Terraform version installed does not meet the requirements. Please see [here](#requirements) and make sure you have fulfilled all the requirements.

### Add Workstations in CAS Manager
Go to the CAS Manager Admin Console and add the newly created workstations using "Add existing remote workstation" in the "Remote Workstations" tab.  Note that it may take a few minutes for the workstation to show up in the "Select workstation from directory" drop-down box.

### Start PCoIP Session
Once the workstations have been added to be managed by CAS Manager and assigned to Active Directory users, a PCoIP user can connect the PCoIP client to the public IP of the CAC, or Load Balancer if one is configured, to start a PCoIP session.

### Changing the deployment
Terraform is a declarative language to describe the desired state of resources. A user can modify `terraform.tfvars` and run `terraform apply` again, and Terraform will try to only apply the changes needed to achieve the new state.

### Deleting the deployment
Run `terraform destroy` to remove all resources created by Terraform.

## Troubleshooting
Please visit the [Troubleshooting](/docs/troubleshooting.md) page for further instructions.
