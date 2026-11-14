import java.util.Properties

plugins {
    id("com.android.application")
    // AGP 9 compiles Kotlin through its built-in Kotlin support.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) keyPropertiesFile.inputStream().use { keyProperties.load(it) }
val signingFields = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val signingEnvironment = mapOf("storeFile" to "FINANCAS_KEYSTORE_PATH",
    "storePassword" to "FINANCAS_STORE_PASSWORD", "keyAlias" to "FINANCAS_KEY_ALIAS",
    "keyPassword" to "FINANCAS_KEY_PASSWORD")
val releaseSigning = signingFields.associateWith {
    providers.environmentVariable(signingEnvironment.getValue(it)).orNull
        ?: keyProperties.getProperty(it)
}
val hasReleaseSigning = releaseSigning.values.all { !it.isNullOrBlank() }
require(hasReleaseSigning || releaseSigning.values.all { it.isNullOrBlank() }) {
    "Assinatura incompleta. Configure os quatro campos de key.properties ou FINANCAS_*; nao informe senhas no comando."
}

android {
    namespace = "com.example.financas_facil"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.financas_facil"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("production") {
                storeFile = rootProject.file(releaseSigning.getValue("storeFile")!!)
                require(storeFile!!.isFile) { "Arquivo de assinatura de producao nao encontrado." }
                storePassword = releaseSigning.getValue("storePassword")
                keyAlias = releaseSigning.getValue("keyAlias")
                keyPassword = releaseSigning.getValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Sem credenciais, gera apenas APK nao assinado para validar compilacao.
            // Nunca recorre silenciosamente a chave de debug.
            signingConfig = if (hasReleaseSigning) signingConfigs.getByName("production") else null
        }
    }
}

val validateProductionSigning = tasks.register("validateProductionSigning") {
    doLast {
        check(hasReleaseSigning) { "Configure a assinatura de producao antes de distribuir o aplicativo." }
    }
}
tasks.matching { it.name.startsWith("bundle") && it.name.endsWith("Release") }.configureEach {
    dependsOn(validateProductionSigning)
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
