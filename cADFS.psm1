﻿enum Ensure {
    Absent;
    Present;
}

#region DSC Resource: cADFSFarm
[DscResource()]
class cADFSFarm {
    <#
    The Ensure property is used to determine if the Active Directory Federation Service (ADFS) should be installed (Present) or not installed (Absent).
    #>
    [DscProperty(Mandatory)]
    [Ensure] $Ensure;

    <#
    The DisplayName property is the name of the Active Directory Federation Service (ADFS) that users will see when they are directed to the authentication page.
    #>
    [DscProperty(Mandatory)]
    [string] $DisplayName;

    <#
    The ServiceName property is the name of the Active Directory Federation Services (ADFS) service. For example: adfs-service.contoso.com.
    #>
    [DscProperty(key)]
    [string] $ServiceName;

    <#
    The CertificateThumbprint property is the thumbprint of the certificate, located in the local computer's certificate store, that will be bound to the 
    Active Directory Federation Service (ADFS) farm.
    #>
    [DscProperty()]
    [string] $CertificateThumbprint;

    <#
    The ServiceCredential property is a PSCredential that represents the username/password that the 
    #>
    [DscProperty(Mandatory)]
    [pscredential] $ServiceCredential;

    <#
    The InstallCredential property is a PSCredential that represents the username/password of an Active Directory user account that is a member of
    the Domain Administrators security group. This account will be used to install Active Directory Federation Services (ADFS).
    #>
    [DscProperty(Mandatory)]
    [pscredential] $InstallCredential;

    [cADFSFarm] Get() {
        Write-Verbose -Message 'Starting retrieving ADFS Farm configuration.';

        try {
            $AdfsProperties = Get-AdfsProperties -ErrorAction Stop;
        }
        catch {
            Write-Verbose -Message ('Error occurred while retrieving ADFS properties: {0}' -f $Error[0].Exception.Message);
            return $false;
        }

        Write-Verbose -Message 'Finished retrieving ADFS Farm configuration.';
        return $this;
    }

    [System.Boolean] Test() {
        # Assume compliance by default
        $Compliant = $true;

        Write-Verbose -Message 'Testing for presence of Active Directory Federation Services (ADFS) farm.';

        $Properties = Get-AdfsProperties;

        if ($this.Ensure -eq 'Present') {
            Write-Verbose -Message 'Checking for presence of ADFS Farm.';
            if ($this.ServiceName -ne $Properties.HostName) {
                Write-Verbose -Message 'ADFS Service Name doesn''t match the desired state.';
                $Compliant = $false;
            }
        }

        if ($this.Ensure -eq 'Absent') {
            Write-Verbose -Message 'Checking for absence of ADFS Farm.';
            if ($Properties) {
                Write-Verbose -Message
                $Compliant = $false;
            }
        }

        return $Compliant;
    }

    [void] Set() {
        ### If ADFS Farm shoud be present, then go ahead and install it.
        if ($this.Ensure -eq [Ensure]::Present) {
            $AdfsProperties = Get-AdfsProperties;
            if (!$AdfsProperties) {
                Write-Verbose -Message 'Installing Active Directory Federation Services (ADFS) farm.';
                $AdfsFarm = @{
                    ServiceCredential = $this.ServiceCredential;
                    InstallCredential = $this.InstallCredential;
                    CertificateThumbprint = $this.CertificateThumbprint;
                    DisplayName = $this.DisplayName;
                    ServiceName = $this.ServiceName;
                    };
                InstallADFSFarm @AdfsFarm;
            }

            if ($AdfsProperties) {
                Write-Verbose -Message 'Configuring Active Directory Federation Services (ADFS) properties.';
                $AdfsProperties = @{
                    DisplayName = $this.DisplayName;
                    };
                Set-AdfsProperties @AdfsProperties;
            }
        }

        if ($this.Ensure -eq [Ensure]::Absent) {
            ### From the help for Remove-AdfsFarmNode: The Remove-AdfsFarmNode cmdlet is deprecated. Instead, use the Uninstall-WindowsFeature cmdlet.
            Uninstall-WindowsFeature -Name ADFS-Federation;
        }

        return;
    }
}


function InstallADFSFarm {
    <#
    .Synopsis
    Performs the configuration

    .Parameter
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [pscredential] $ServiceCredential,
        [Parameter(Mandatory = $true)]
        [pscredential] $InstallCredential,
        [Parameter(Mandatory = $true)]
        [pscredential] $CertificateThumbprint,
        [Parameter(Mandatory = $true)]
        [pscredential] $DisplayName,
        [Parameter(Mandatory = $true)]
        [pscredential] $ServiceName

    )
    Install-AdfsFarm `
        -CertificateThumbprint:"60E5A409A0011E57FB9C77CBBCB077F4817299D1" `
        -Credential:$installationCredential `
        -FederationServiceDisplayName:"HC Lab Corporation" `
        -FederationServiceName:"adfs-service.hclab.local" `
        -OverwriteConfiguration:$true `
        -ServiceAccountCredential:$serviceAccountCredential;            
}
#endregion

#region DSC Resource: cADFSRelyingPartyTrust
[DscResource()]
class cADFSRelyingPartyTrust {
    [DscProperty(Key)]
    [string] $Identifier;

    # .Description
    # This property does some cool stuff.
    [DscProperty()]
    [bool] $Property2;

    [cADFSRelyingPartyTrust] Get() {
        $RelyingPartyTrust = [cADFSRelyingPartyTrust]::new();
        return $RelyingPartyTrust;
    }

    [bool] Test() {
        return $false;
    }

    [void] Set() {
    }
}
#endregion

#region DSC Resource: cADFSGlobalAuthenticationPolicy
[DscResource()]
class cADFSGlobalAuthenticationPolicy {
    [DscProperty(Key, NotConfigurable)]
    [string] $Name = 'Policy';
    
    [DscProperty()]
    [bool] $DeviceAuthenticationEnabled = $false;

    [DscProperty()]
    [string[]] $PrimaryExtranetAuthenticationProvider = @('FormsAuthentication');

    [DscProperty()]
    [string[]] $PrimaryIntranetAuthenticationProvider = @('WindowsAuthentication');

    [DscProperty()]
    [string[]] $AdditionalAuthenticationProvider = @();

    [DscProperty()]
    [bool] $WindowsIntegratedFallbackEnabled = $true;

    ### Retrieves the current state of the ADFS Global Authentication Policy.
    [cADFSGlobalAuthenticationPolicy] Get() {
        Write-Verbose -Message 'Starting retrieving configuration for ADFS Global Authentication Policy.';
        $CurrentPolicy = Get-AdfsGlobalAuthenticationPolicy;

        $this.PrimaryExtranetAuthenticationProvider = $CurrentPolicy.PrimaryExtranetAuthenticationProvider;
        $this.PrimaryIntranetAuthenticationProvider = $CurrentPolicy.PrimaryIntranetAuthenticationProvider;
        $this.AdditionalAuthenticationProvider = $CurrentPolicy.AdditionalAuthenticationProvider;
        $this.DeviceAuthenticationEnabled = $CurrentPolicy.DeviceAuthenticationEnabled;

        Write-Verbose -Message 'Finished retrieving configuration for ADFS Global Authentication Policy.';
        return $this;
    }

    ### Tests the validity of the current policy against the 
    [bool] Test() {
        Write-Verbose -Message 'Starting evaluating ADFS Global Authentication Policy against desired state.';

        $CurrentPolicy = Get-AdfsGlobalAuthenticationPolicy;

        $Compliance = $true;

        if ($this.PrimaryExtranetAuthenticationProvider -ne $CurrentPolicy.PrimaryExtranetAuthenticationProvider) {
            Write-Verbose -Message 'Primary Extranet Authentication Provider does not match desired configuration.';
            $Compliance = $false;
        }
        if ($this.PrimaryIntranetAuthenticationProvider -ne $CurrentPolicy.PrimaryIntranetAuthenticationProvider) {
            Write-Verbose -Message 'Primary Intranet Authentication Provider does not match desired configuration.';
            $Compliance = $false;
        }
        if ($this.AdditionalAuthenticationProvider -ne $CurrentPolicy.AdditionalAuthenticationProvider) {
            Write-Verbose -Message 'Additional Authentication Provider does not match desired configuration.';
            $Compliance = $false;
        }
        if ($this.DeviceAuthenticationEnabled -ne $CurrentPolicy.DeviceAuthenticationEnabled) {
            Write-Verbose -Message 'Device Authentication setting does not match desired configuration.';
            $Compliance = $false;
        }
        if ($this.WindowsIntegratedFallbackEnabled -ne $CurrentPolicy.WindowsIntegratedFallbackEnabled) {
            Write-Verbose -Message 'Windows Integrated Fallback setting does not match desired configuration.';
            $Compliance = $false;
        }

        Write-Verbose -Message 'All ADFS Global Authentication settings match desired configuration.';
        return $Compliance;
    }

    [void] Set() {
        Write-Verbose -Message 'Starting setting ADFS Global Authentication configuration.';
        $GlobalAuthenticationPolicy = @{
            PrimaryExtranetAuthenticationProvider = $this.PrimaryExtranetAuthenticationProvider;
            PrimaryIntranetAuthenticationProvider = $this.PrimaryIntranetAuthenticationProvider;
            AdditionalAuthenticationProvider = $this.AdditionalAuthenticationProvider;
            DeviceAuthenticationEnabled = $this.DeviceAuthenticationEnabled;
            WindowsIntegratedFallbackEnabled = $this.WindowsIntegratedFallbackEnabled;
            };
        Set-AdfsGlobalAuthenticationPolicy;
        Write-Verbose -Message 'Finished setting ADFS Global Authentication configuration.';
    }
}
#endregion

return;

<#
####### DOESN'T WORK DUE TO BUG #######
####### https://connect.microsoft.com/PowerShell/feedback/details/1191366

Write-Host -Object 'Loading cADFS module';

#region Import DSC Resources
$ResourceList = Get-ChildItem -Path $PSScriptRoot\Resources;

foreach ($Resource in $ResourceList) {
    Write-Verbose -Message ('Loading DSC resource from {0}' -f $Resource.FullName);
    . $Resource.FullName;
}
#endregion

Write-Host -Object 'Finished loading module.';
#>