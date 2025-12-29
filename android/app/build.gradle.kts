import java.util.Properties
import java.io.File
import com.android.build.gradle.internal.dsl.BaseAppModuleExtension

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// --------------------------------------------------------------------------
// BÖLÜM A: HARİCİ PAROLALARI VE YOLU OKUYAN TANIMLAMALAR
// --------------------------------------------------------------------------

val flutterRoot = rootProject.projectDir.parentFile!!.absolutePath
val localProperties = Properties()
val localPropertiesFile = File(flutterRoot, "local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val keystoreProperties = Properties()
val keystorePropertiesFile = File(flutterRoot, "android/key.properties")

if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val signingStoreFileProperty: String? = keystoreProperties.getProperty("storeFile")
val signingKeyAlias: String? = keystoreProperties.getProperty("keyAlias")
val signingStorePassword: String? = keystoreProperties.getProperty("storePassword")
val signingKeyPassword: String? = keystoreProperties.getProperty("keyPassword")

// --------------------------------------------------------------------------

android {
    namespace = "com.example.doviz_takip_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.dovizcepte.canlikur" 
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    
    // YAYIN İMZALAMA AYARLARI
    signingConfigs {
        create("release") {
            if (signingStoreFileProperty != null) {
                // KRİTİK DÜZELTME: Dosyayı android/app'den değil, BİR ÜST KLASÖRDEN (Kök dizin) aramasını sağladık.
                storeFile = file("../" + signingStoreFileProperty!!) 
                storePassword = signingStorePassword
                keyAlias = signingKeyAlias
                keyPassword = signingKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release") 
            isMinifyEnabled = true 
        }
    }
}

flutter {
    source = "../.."
}