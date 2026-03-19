// Root build script to anchor the Gradle project

plugins {
    // Allows the root project to be recognized as a standard Gradle build by the IDE
    base
}

tasks.register("buildAll") {
    group = "build"
    description = "Builds all included builds"
    dependsOn(gradle.includedBuilds.map { it.task(":build") })
}
