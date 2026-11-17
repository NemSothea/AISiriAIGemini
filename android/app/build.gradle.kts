plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.ksp)
    alias(libs.plugins.compose.compiler)
}

android {
    namespace = "com.example.voicebank"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.example.voicebank"
        // App runs on Android 10+; AppFunctions (Gemini) activate only on API 36+.
        minSdk = 29
        targetSdk = 37
        versionCode = 1
        versionName = "0.1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures { compose = true }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.biometric)
    implementation(libs.androidx.fragment.ktx)
    implementation(libs.zxing.core)

    // AppFunctions (Gemini / Android MCP)
    implementation(libs.androidx.appfunctions)
    ksp(libs.androidx.appfunctions.compiler)

    testImplementation(libs.junit)
}
