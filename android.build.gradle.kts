subprojects {
    afterEvaluate {
        if (hasProperty("android")) {
            extensions.configure<com.android.build.gradle.BaseExtension> {
                compileSdkVersion(36)
            }
        }
    }
}
