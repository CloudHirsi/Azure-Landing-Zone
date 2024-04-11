# *Azure Landing Zone Project*
## **Architecture:** 
![image](https://github.com/CloudHirsi/Azure-Landing-Zone/assets/153539293/1779e690-cebf-4136-b339-560be9568365)

## **Terraform:**
![image](https://github.com/CloudHirsi/Azure-Landing-Zone/assets/153539293/3a103834-6cf4-463a-9f30-14160de49f9f)

## **Azure DevOps Pipeline:**
Build Pipeline:
![image](https://github.com/CloudHirsi/Azure-Landing-Zone/assets/153539293/28c9d03b-f019-4a01-8048-3c77d013bf3f)
YAML:
``` YAML
trigger: 
- main

stages:
- stage: Build
  jobs:
  - job: Build
    pool:
      vmImage: 'ubuntu-latest'
    steps:
    - checkout: self
      path: src
      clean: true
    - task: TerraformInstaller@1
      inputs:
        terraformVersion: 'latest'

    - task: CmdLine@2
      displayName: 'Download and Install Trivy vulnerability scanner'
      inputs:
        script: |
          sudo apt-get install rpm
           wget https://github.com/aquasecurity/trivy/releases/download/v0.20.0/trivy_0.20.0_Linux-64bit.deb
          sudo dpkg -i trivy_0.20.0_Linux-64bit.deb
          trivy -v

    - task: TerraformTaskV4@4
      displayName: Tf init
      inputs:
        provider: 'azurerm'
        command: 'init'
        backendServiceArm: Azure
        backendAzureRmResourceGroupName: 'tfstate'
        backendAzureRmStorageAccountName: 'tfbackend7890'
        backendAzureRmContainerName: 'tfbackend'
        backendAzureRmKey: 'prod.terraform.tfstate'

    - task: CmdLine@2
      displayName: 'LOW/MED - Trivy vulnerability scanner in IaC mode'
      inputs:
        script: |
          for file in $(find /home/vsts/work/1/src -name "*.tf"); do
              trivy config --severity LOW,MEDIUM --exit-code 0 "$file"
          done


    - task: CmdLine@2
      displayName: 'HIGH/CRIT - Trivy vulnerability scanner in IaC mode'
      inputs:
        script: |
          for file in $(find /home/vsts/work/1/src -name "*.tf"); do
              trivy config --severity HIGH,CRITICAL --exit-code 0 "$file"
          done

    - task: TerraformTaskV4@4
      displayName: Tf plan
      inputs:
        provider: 'azurerm'
        command: 'plan'
        commandOptions: '-out $(Build.SourcesDirectory)/tfplanfile'
        environmentServiceNameAzureRM: Azure
            
    - task: CopyFiles@2
      displayName: 'Copy Files to Staging'
      inputs:
        SourceFolder: '$(Agent.BuildDirectory)/src'
        Contents: 'Terraform/**'
        TargetFolder: '$(Build.ArtifactStagingDirectory)'
    - task: ArchiveFiles@2
      displayName: Archive files
      inputs:
        rootFolderOrFile: '$(Build.SourcesDirectory)/'
        includeRootFolder: false
        archiveType: 'zip'
        archiveFile: '$(Build.ArtifactStagingDirectory)/$(Build.BuildId).zip'
        replaceExistingArchive: true

    - task: PublishBuildArtifacts@1
      inputs:
        PathtoPublish: '$(Build.ArtifactStagingDirectory)'
        ArtifactName: '$(Build.BuildId)-build'
        publishLocation: 'Container'
```

Release Pipeline:
![image](https://github.com/CloudHirsi/Azure-Landing-Zone/assets/153539293/1ac16cdd-fa85-4d1f-8444-46deef9bcbcb)

Deploy and Destroy Stages:

![image](https://github.com/CloudHirsi/Azure-Landing-Zone/assets/153539293/91716b23-cc34-4de6-a827-529416275b2c) ![image](https://github.com/CloudHirsi/Azure-Landing-Zone/assets/153539293/d9b1b5d3-f12c-43da-96f5-eb2add05e0c3)


## **Azure Resources:**
![image](https://github.com/CloudHirsi/Azure-Landing-Zone/assets/153539293/5a4d8ba8-1455-4fa9-8f73-8fb952d375d4)




