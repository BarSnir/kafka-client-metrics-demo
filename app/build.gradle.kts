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

val producerPropsPath = rootProject.layout.projectDirectory.file("config/producer.properties").asFile.absolutePath
val consumerPropsPath = rootProject.layout.projectDirectory.file("config/consumer.properties").asFile.absolutePath
val producerJmxPath = rootProject.layout.projectDirectory.file("prometheus/jmx-kafka-producer.yml").asFile.absolutePath
val consumerJmxPath = rootProject.layout.projectDirectory.file("prometheus/jmx-kafka-consumer.yml").asFile.absolutePath

// Run both producers in parallel:
//   Terminal 1: ./gradlew :app:runProducerSlow
//   Terminal 2: ./gradlew :app:runProducerFast
// Metrics: slow → localhost:9091, fast → localhost:9092
tasks.register<JavaExec>("runProducerSlow") {
    group = "demo"
    description = "Run the SLOW producer (linger.ms=20, batch.size=64KB) — metrics on :9091"
    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("com.demo.app.DemoProducer")
    args = listOf(producerPropsPath)
    jvmArgs(
        "-javaagent:${jmxExporter.asPath}=9091:${producerJmxPath}",
        "-Dproducer.profile=SLOW"
    )
}

tasks.register<JavaExec>("runProducerFast") {
    group = "demo"
    description = "Run the FAST producer (linger.ms=0, batch.size=0) — metrics on :9092"
    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("com.demo.app.DemoProducer")
    args = listOf(producerPropsPath)
    jvmArgs(
        "-javaagent:${jmxExporter.asPath}=9092:${producerJmxPath}",
        "-Dproducer.profile=FAST"
    )
}

// Run both consumers in parallel:
//   Terminal 1: ./gradlew :app:runConsumerSlow
//   Terminal 2: ./gradlew :app:runConsumerFast
// Metrics: slow → localhost:9093, fast → localhost:9094
tasks.register<JavaExec>("runConsumerSlow") {
    group = "demo"
    description = "Run the SLOW consumer (fetch.min.bytes=1MB, fetch.max.wait.ms=5000) — metrics on :9093"
    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("com.demo.app.DemoConsumer")
    args = listOf(consumerPropsPath)
    jvmArgs(
        "-javaagent:${jmxExporter.asPath}=9093:${consumerJmxPath}",
        "-Dconsumer.profile=SLOW"
    )
}

tasks.register<JavaExec>("runConsumerFast") {
    group = "demo"
    description = "Run the FAST consumer (fetch.min.bytes=1, fetch.max.wait.ms=50) — metrics on :9094"
    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("com.demo.app.DemoConsumer")
    args = listOf(consumerPropsPath)
    jvmArgs(
        "-javaagent:${jmxExporter.asPath}=9094:${consumerJmxPath}",
        "-Dconsumer.profile=FAST"
    )
}
