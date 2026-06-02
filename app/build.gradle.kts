plugins {
    id("buildlogic.java-application-conventions")
    id("com.github.davidmc24.gradle.plugin.avro") version "1.9.1"
}

repositories {
    maven { url = uri("https://packages.confluent.io/maven/") }
}

val jmxExporter by configurations.creating {
    isTransitive = false
}

dependencies {
    implementation("org.apache.kafka:kafka-clients:3.7.0")
    implementation("io.confluent:kafka-avro-serializer:7.6.0")
    implementation("org.apache.avro:avro:1.11.3")
    jmxExporter("io.prometheus.jmx:jmx_prometheus_javaagent:0.20.0")
}

avro {
    stringType.set("String")
}

application {
    mainClass = "com.demo.app.DemoProducer"
}

// Run both producers in parallel:
//   Terminal 1: ./gradlew :app:runProducerSlow
//   Terminal 2: ./gradlew :app:runProducerFast
// Metrics: slow → localhost:9091, fast → localhost:9092
tasks.register<JavaExec>("runProducerSlow") {
    group = "demo"
    description = "Run the SLOW producer (linger.ms=20, batch.size=64KB) — metrics on :9091"
    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("com.demo.app.DemoProducer")
    args = listOf("${rootProject.projectDir}/config/producer.properties")
    doFirst {
        jvmArgs(
            "-javaagent:${jmxExporter.singleFile}=9091:${rootProject.projectDir}/prometheus/jmx-kafka-producer.yml",
            "-Dproducer.profile=SLOW"
        )
    }
}

tasks.register<JavaExec>("runProducerFast") {
    group = "demo"
    description = "Run the FAST producer (linger.ms=0, batch.size=0) — metrics on :9092"
    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("com.demo.app.DemoProducer")
    args = listOf("${rootProject.projectDir}/config/producer.properties")
    doFirst {
        jvmArgs(
            "-javaagent:${jmxExporter.singleFile}=9092:${rootProject.projectDir}/prometheus/jmx-kafka-producer.yml",
            "-Dproducer.profile=FAST"
        )
    }
}
