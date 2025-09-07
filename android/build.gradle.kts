subprojects {
    project.afterEvaluate {
        if(project.name == "speech_to_text") {
            android {
                namespace = "com.csdcorp.speech_to_text"
            }
        }
    }
}
