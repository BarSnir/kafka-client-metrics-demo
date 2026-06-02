plugins {
    java
    application
    id("com.github.johnrengelman.shadow") version "8.1.1"
}

repositories {
    mavenCentral()
    maven {
        url = uri("https://packages.confluent.io/maven/")
    }
}

dependencies {
    implementation("org.apache.kafka:kafka-clients:3.9.0")
    implementation("io.confluent:kafka-avro-serializer:7.8.0")
    implementation("org.apache.avro:avro:1.11.3")
    implementation("org.slf4j:slf4j-simple:2.0.12")
}

application {
    mainClass.set("com.demo.DemoProducer")
}

tasks.withType<JavaCompile> {
    options.release.set(11)
}

tasks.shadowJar {
    archiveClassifier.set("all")
}