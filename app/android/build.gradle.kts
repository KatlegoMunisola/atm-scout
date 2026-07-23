import org.gradle.authentication.http.BasicAuthentication

allprojects {
    repositories {
        google()
        mavenCentral()
        // Mapbox's private Maven repo, needed to fetch the native Maps SDK.
        // Requires a MAPBOX_DOWNLOADS_TOKEN (a *secret* Mapbox token with the
        // "Downloads:Read" scope, different from the public access token used
        // in app/.env) defined in your user-level ~/.gradle/gradle.properties
        // -- never commit this token to the repo.
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication {
                create<BasicAuthentication>("basic")
            }
            credentials {
                username = "mapbox"
                password = providers.gradleProperty("MAPBOX_DOWNLOADS_TOKEN").getOrElse("")
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
