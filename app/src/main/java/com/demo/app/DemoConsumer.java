package com.demo.app;

import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;

import java.io.FileInputStream;
import java.io.IOException;
import java.time.Duration;
import java.util.Collections;
import java.util.Properties;

public class DemoConsumer {

    public static void main(String[] args) throws IOException {
        if (args.length < 1) {
            System.err.println("Usage: DemoConsumer <path-to-consumer.properties>");
            System.exit(1);
        }

        Properties fileProps = loadProperties(args[0]);
        Properties kafkaProps = buildKafkaProps(fileProps);

        String profile = resolveProfile(fileProps);
        String topic = required(fileProps, "topic");

        try (KafkaConsumer<String, Object> consumer = new KafkaConsumer<>(kafkaProps)) {
            consumer.subscribe(Collections.singletonList(topic));
            System.out.println(">>> Consumer started | profile=" + profile + " | topic=" + topic);

            long totalRecords = 0;
            while (true) {
                ConsumerRecords<String, Object> records = consumer.poll(Duration.ofMillis(100));
                if (!records.isEmpty()) {
                    for (ConsumerRecord<String, Object> ignored : records) {
                        // Access each record to force deserialization and surface errors immediately.
                    }
                    totalRecords += records.count();
                    if (totalRecords % 10000 < records.count()) {
                        System.out.println(">>> Consumed " + totalRecords + " records | profile=" + profile);
                    }
                }
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
        String profile = resolveProfile(fileProps);
        String prefix = "FAST".equals(profile) ? "fast" : "slow";

        String kafkaKey = required(fileProps, prefix + ".kafka.api.key");
        String kafkaSecret = required(fileProps, prefix + ".kafka.api.secret");
        String srKey = required(fileProps, prefix + ".sr.api.key");
        String srSecret = required(fileProps, prefix + ".sr.api.secret");

        Properties props = new Properties();
        props.put("bootstrap.servers", required(fileProps, "bootstrap.servers"));
        props.put("schema.registry.url", required(fileProps, "schema.registry.url"));
        props.put("security.protocol", "SASL_SSL");
        props.put("sasl.mechanism", "PLAIN");
        props.put("sasl.jaas.config", String.format(
            "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"%s\" password=\"%s\";",
            kafkaKey, kafkaSecret));
        props.put("basic.auth.credentials.source", "USER_INFO");
        props.put("basic.auth.user.info", srKey + ":" + srSecret);
        props.put("group.id", "FAST".equals(profile) ? "fast-group" : "slow-group");
        props.put("client.id", "demo-consumer-" + profile.toLowerCase());
        props.put("enable.auto.commit", "true");
        props.put("auto.offset.reset", "earliest");
        props.put("specific.avro.reader", "false");
        props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, required(fileProps, "key.deserializer"));
        props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, required(fileProps, "value.deserializer"));
        if ("FAST".equals(profile)) {
            props.put(ConsumerConfig.FETCH_MIN_BYTES_CONFIG, "1");
            props.put(ConsumerConfig.FETCH_MAX_WAIT_MS_CONFIG, "50");
            props.put(ConsumerConfig.MAX_PARTITION_FETCH_BYTES_CONFIG, "65536");
        } else {
            props.put(ConsumerConfig.FETCH_MIN_BYTES_CONFIG, "1048576");
            props.put(ConsumerConfig.FETCH_MAX_WAIT_MS_CONFIG, "5000");
            props.put(ConsumerConfig.MAX_PARTITION_FETCH_BYTES_CONFIG, "1048576");
        }

        return props;
    }

    private static String resolveProfile(Properties fileProps) {
        String sysProp = System.getProperty("consumer.profile");
        return (sysProp != null && !sysProp.isBlank())
            ? sysProp.toUpperCase()
            : fileProps.getProperty("profile", "SLOW").toUpperCase();
    }

    private static String required(Properties props, String key) {
        String value = props.getProperty(key);
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("Missing required config: " + key);
        }
        return value;
    }
}