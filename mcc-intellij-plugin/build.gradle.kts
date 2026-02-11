plugins {
    id("java")
    id("org.jetbrains.kotlin.jvm") version "1.9.21"
    id("org.jetbrains.intellij") version "1.16.1"
}

group = "com.mcc"
version = "1.0.0"

repositories {
    mavenCentral()
}

// Note: Do NOT add kotlin-stdlib or kotlinx-coroutines dependencies!
// They are already provided by the IntelliJ Platform.
// Adding them will cause ClassLoader conflicts.
dependencies {
    // Add only non-Kotlin dependencies here if needed
}

// Configure Gradle IntelliJ Plugin
intellij {
    version.set("2024.1")
    type.set("IC") // IntelliJ IDEA Community Edition
    
    plugins.set(listOf(
        // Add any required plugin dependencies here
    ))
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}

tasks {
    withType<JavaCompile> {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }
    
    withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
        kotlinOptions.jvmTarget = "17"
    }

    patchPluginXml {
        sinceBuild.set("241")
        untilBuild.set("251.*")
    }

    signPlugin {
        certificateChain.set(System.getenv("CERTIFICATE_CHAIN"))
        privateKey.set(System.getenv("PRIVATE_KEY"))
        password.set(System.getenv("PRIVATE_KEY_PASSWORD"))
    }

    publishPlugin {
        token.set(System.getenv("PUBLISH_TOKEN"))
    }
    
    buildSearchableOptions {
        enabled = false
    }
}

kotlin {
    jvmToolchain(17)
}

