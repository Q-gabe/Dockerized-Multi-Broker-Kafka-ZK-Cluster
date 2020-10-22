# Dockerized-Multi-Broker-Kafka-ZK-Cluster
A multi-broker Kafka cluster setup managed by a Zookeeper ensemble configured to run in Docker using Docker Compose. 

## Getting Started
This is a quick start guide. For a more in-depth guide, please check [guide.md](https://github.com/Q-gabe/Dockerized-Multi-Broker-Kafka-ZK-Cluster/blob/master/guide.md). _(Highly recommended if you are new to running Kafka on Docker)_

### Requirements
* Ensure you have [Docker](https://docs.docker.com/get-docker/) and [Docker Compose]() installed.
  
  (Alternatively, install [Docker Desktop](https://www.docker.com/products/docker-desktop) which installs both)

* Ensure that you have [kafkacat](https://github.com/edenhill/kafkacat) installed.

### Setting up
1. Clone the repository and navigate to it.
   ```
   git clone https://github.com/Q-gabe/Dockerized-Multi-Broker-Kafka-ZK-Cluster.git
   cd Dockerized-Multi-Broker-Kafka-ZK-Cluster
   ```

2. Run all images using Docker Compose. Keep terminal open to observe logs (you can use `-d` if this is not desired).
   ```
   docker-compose up
   ```

3. Wait and check that all containers are running (Up state):
   ```
   docker-compose ps
   ```

### Creating a topic, publishing and consuming messages
4. Create a topic using the included shell file.
   ```
   ./create-topic.sh testTopic
   ```

5. Publish messages to the topic using kafkacat. Messages are new-line delimited and transmission is terminated with <kbd>Ctrl</kbd> + <kbd>D</kbd>.
   ```
   kafkacat -b localhost:32001 -t testTopic -P
   42
   test test
   ```

6. Consume the messages from the topic in a similar fashion. End the transaction with <kbd>Ctrl</kbd> + <kbd>C</kbd>.
   ```
   kafkacat -b localhost:32001 -t testTopic -C
   # Output
   42
   test test
   % Reached end of topic testTopic [0] at offset 2
   ```

### Observing Fault Tolerance / Re-election
7. Delete a Broker and Zookeeper.
   ```
   docker kill kafka2
   docker kill zoo2
   ```

8. Test steps 4-6 again to observe that messaging is still working.

### Shutting down
9. Shut down and remove all containers when done.
   ```
   docker-compose down
   ```

For observing fault tolerance in the case of controller Broker or leader Zookeeper server, please check [the first](https://github.com/Q-gabe/Dockerized-Multi-Broker-Kafka-ZK-Cluster/blob/master/guide.md#stage-4---observing-fault-tolerance-leader-partition--controller-re-election) and [the second section](https://github.com/Q-gabe/Dockerized-Multi-Broker-Kafka-ZK-Cluster/blob/master/guide.md#stage-5---observing-fault-tolerance-zookeeper-leader-re-election) on Observing Tolerance of the guide.

## Network topology
![Network Topology](https://raw.githubusercontent.com/Q-gabe/Dockerized-Multi-Broker-Kafka-ZK-Cluster/main/assets/NetworkDiagram.png)

For an explanation on the network, please check [the network appendix](https://github.com/Q-gabe/Dockerized-Multi-Broker-Kafka-ZK-Cluster/blob/master/guide.md#appendix--network-setup) of the guide.

## Helpful links
Here are a few links that helped me a substantial bit:

*  Networking for Internal and External networking for Kafka Brokers in Docker:
   * [This incredible and visual blogpost by rmoff](https://rmoff.net/2018/08/02/kafka-listeners-explained/)
   * [wurstmeister’s own connectivity walkthrough](https://github.com/wurstmeister/kafka-docker/wiki/Connectivity)
*  [Replicated mode for Zookeeper servers](https://zookeeper.apache.org/doc/current/zookeeperStarted.html#sc_RunningReplicatedZooKeeper)
* [Using kafkacat to produce and consume messages](https://docs.confluent.io/current/app-development/kafkacat-usage.html)


## Acknowledgements
This has been built in fulfillment of OTOT Task D for the module CS3219 AY20/21 S1 of the National University of Singapore.

## License
[MIT](https://github.com/Q-gabe/Dockerized-Multi-Broker-Kafka-ZK-Cluster/blob/master/LICENSE)