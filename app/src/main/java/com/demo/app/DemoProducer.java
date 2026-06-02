package com.demo.app;

import org.apache.kafka.clients.producer.*;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.Properties;
import java.util.UUID;

public class DemoProducer {

    public static void main(String[] args) throws InterruptedException, IOException {
        if (args.length < 1) {
            System.err.println("Usage: DemoProducerSlowProducer <path-to-producer.properties>");
            System.exit(1);
        }

        Properties fileProps = loadProperties(args[0]);
        Properties kafkaProps = buildKafkaProps(fileProps);

        KafkaProducer<String, UserEvent> producer = new KafkaProducer<>(kafkaProps);
        String topic = "user-events";
        String profile = fileProps.getProperty("profile", "SLOW").toUpperCase();
        System.out.println(">>> Producer started | profile=" + profile);

        while (true) {
            long startTime = System.currentTimeMillis();

            for (int i = 0; i < 100000; i++) {
                String eventId = UUID.randomUUID().toString();
                UserEvent event = new UserEvent(eventId, startTime, "bsnir-metrics-v3.9-payload-data");
                ProducerRecord<String, UserEvent> record = new ProducerRecord<>(topic, eventId, event);
                producer.send(record, (metadata, exception) -> {
                    if (exception != null) {
                        System.err.println("Failed to send record: " + exception.getMessage());
                    }
                });
            }

            long elapsedTime = System.currentTimeMillis() - startTime;
            long sleepTime = 50 - elapsedTime;
            if (sleepTime > 0) {
                Thread.sleep(sleepTime);
            }
        }
    }

    private static Properties loadProperties(String path) throws IOException {
        Properties props = new Properties();
        try (FileInputStream fis = new FileInputStream(path)) {
            props.load(fis);
        }
        return props;
    }

    private static Properties buildKafkaProps(Properties fileProps) {
        // -Dproducer.profile=SLOW|FAST lets the Gradle task override the file value
        String sysProp = System.getProperty("producer.profile");
        String profile = (sysProp != null && !sysProp.isBlank())
            ? sysProp.toUpperCase()
            : fileProps.getProperty("profile", "SLOW").toUpperCase();
        String prefix = "FAST".equals(profile) ? "fast" : "slow";

        String kafkaKey    = required(fileProps, prefix + ".kafka.api.key");
        String kafkaSecret = required(fileProps, prefix + ".kafka.api.secret");
        String srKey       = required(fileProps, prefix + ".sr.api.key");
        String srSecret    = required(fileProps, prefix + ".sr.api.secret");

        Properties props = new Properties();
        props.put("bootstrap.servers",   required(fileProps, "bootstrap.servers"));
        props.put("schema.registry.url", required(fileProps, "schema.registry.url"));
        props.put("security.protocol",   "SASL_SSL");
        props.put("sasl.mechanism",      "PLAIN");
        props.put("sasl.jaas.config",    String.format(
            "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"%s\" password=\"%s\";",
            kafkaKey, kafkaSecret));
        props.put("basic.auth.credentials.source", "USER_INFO");
        props.put("basic.auth.user.info", srKey + ":" + srSecret);
        props.put("auto.register.schemas", "false");
        props.put("use.latest.version",    "true");
        props.put("client.id", "demo-producer-" + profile.toLowerCase());
        props.put("key.serializer",   required(fileProps, "key.serializer"));
        props.put("value.serializer", required(fileProps, "value.serializer"));
        if ("FAST".equals(profile)) {
            props.put(ProducerConfig.LINGER_MS_CONFIG,          "100");
            props.put(ProducerConfig.BATCH_SIZE_CONFIG,         "100000");
        } else {
            props.put(ProducerConfig.LINGER_MS_CONFIG,          "1000");
            props.put(ProducerConfig.BATCH_SIZE_CONFIG,         "1000000");
        }
        return props;
    }

    private static String required(Properties props, String key) {
        String value = props.getProperty(key);
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("Missing required config: " + key);
        }
        return value;
    }
}
