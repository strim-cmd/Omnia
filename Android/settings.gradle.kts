pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "Omnia"

include(":app")
include(":core:common")
include(":core:domain")
include(":core:application")
include(":core:data")
include(":core:security")
include(":core:designsystem")
include(":feature:chat")
include(":feature:providers")
include(":feature:settings")
