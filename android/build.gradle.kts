// File: android/build.gradle.kts

allprojects {
    repositories {
        google()
        mavenCentral()
        // THÊM DÒNG NÀY VÀO VỚI CÚ PHÁP CỦA KOTLIN
        maven { url = uri("https://github.com/SceneView/sceneform-android/raw/main/maven-repository") }
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