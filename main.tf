terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

resource "azurerm_storage_account" "imports_service_sa" {
  name     = "stgsangimportssane001"
  location = "northeurope"

  account_tier                     = "Standard"
  account_replication_type         = "LRS" /*  GRS, RAGRS, ZRS, GZRS, RAGZRS */
  access_tier                      = "Cool"
  account_kind             = "StorageV2"

  resource_group_name = azurerm_resource_group.product_service_rg.name
}

resource "azurerm_storage_container" "imports_service_sa_container" {
  name                  = "uploaded"
  storage_account_name  = azurerm_storage_account.imports_service_sa.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "imports_service_sa_blob" {
  name                   = "storage-blob-content"
  storage_account_name   = azurerm_storage_account.imports_service_sa.name
  storage_container_name = azurerm_storage_container.imports_service_sa_container.name
  type                   = "Block"
  access_tier            = "Cool"
}

resource "azurerm_storage_share" "imports_service_sa" {
  name  = "sa-imports-service-share"
  quota = 2

  storage_account_name = azurerm_storage_account.imports_service_sa.name
}

resource "azurerm_service_plan" "import_service_plan" {
  name     = "asp-import-service-sand-ne-001"
  location = "northeurope"

  os_type  = "Windows"
  sku_name = "Y1"

  resource_group_name = azurerm_resource_group.product_service_rg.name
}

resource "azurerm_application_insights" "imports_service_fa" {
  name             = "appins-fa-imports-service-sand-ne-001"
  application_type = "web"
  location         = "northeurope"


  resource_group_name = azurerm_resource_group.product_service_rg.name
}


resource "azurerm_windows_function_app" "imports_service" {
  name     = "fa-imports-service-ne-001"
  location = "northeurope"

  service_plan_id     = azurerm_service_plan.import_service_plan.id
  resource_group_name = azurerm_resource_group.product_service_rg.name

  storage_account_name       = azurerm_storage_account.imports_service_sa.name
  storage_account_access_key = azurerm_storage_account.imports_service_sa.primary_access_key

  functions_extension_version = "~4"
  builtin_logging_enabled     = false

  site_config {
    always_on = false

    application_insights_key               = azurerm_application_insights.imports_service_fa.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.imports_service_fa.connection_string

    # For production systems set this to false, but consumption plan supports only 32bit workers
    use_32_bit_worker = true

    # Enable function invocations from Azure Portal.
    cors {
      allowed_origins = ["https://portal.azure.com"]
    }

    application_stack {
      node_version = "~16"
    }
  }

  app_settings = {
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = azurerm_storage_account.imports_service_sa.primary_connection_string
    WEBSITE_CONTENTSHARE                     = azurerm_storage_share.imports_service_sa.name
  }

  # The app settings changes cause downtime on the Function App. e.g. with Azure Function App Slots
  # Therefore it is better to ignore those changes and manage app settings separately off the Terraform.
  lifecycle {
    ignore_changes = [
      app_settings,
      tags["hidden-link: /app-insights-instrumentation-key"],
      tags["hidden-link: /app-insights-resource-id"],
      tags["hidden-link: /app-insights-conn-string"]
    ]
  }
}