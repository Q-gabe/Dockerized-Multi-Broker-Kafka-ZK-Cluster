# In-depth guide to Dockerized-Multi-Broker-Kafka-ZK-Cluster
This document is meant as an in-depth walkthrough into running the setup in Docker and interacting with the Kafka brokers and giving a better understanding into setup. We also investigate how Kafka manages fault-tolerance on Brokers and for Zookeepers.

## Prerequisites:
* Ensure you have [Docker](https://docs.docker.com/get-docker/) and [Docker Compose]() installed.
  
  (Alternatively, install [Docker Desktop](https://www.docker.com/products/docker-desktop) which installs both)

* Ensure that you have [kafkacat](https://github.com/edenhill/kafkacat) installed.


## **Stage 1** – Setting up the Kafka Zookeeper Ensemble & Kafka Nodes

1.	Clone this repository and navigate to it:
    ```
    git clone https://github.com/Q-gabe/Dockerized-Multi-Broker-Kafka-ZK-Cluster.git
    cd Dockerized-Multi-Broker-Kafka-ZK-Cluster
    ```

2.	Ensure that Docker Desktop is installed and running on your system.

3.	Use Docker Compose to orchestrate the local deployment of the Kafka Zookeeper Ensemble & Kafka Nodes:
    ```
    docker-compose up
    ```
    Leave this terminal open to observe the logs from the containers.

    Wait for the images to be pulled from Docker Hub and deployed into the container. You can check that all the Zookeeper servers and Kafka broker nodes are live by running this command in a new terminal:
    ```
    docker-compose ps
    ```

    You should see the following result where all containers (`kafka1-3`, `zoo1-3` have the state “`Up`”):
    ```
    Name               Command               State                          Ports                        
    kafka1   start-kafka.sh                   Up      0.0.0.0:32001->32001/tcp                            
    kafka2   start-kafka.sh                   Up      0.0.0.0:32002->32002/tcp                            
    kafka3   start-kafka.sh                   Up      0.0.0.0:32003->32003/tcp                            
    zoo1     /docker-entrypoint.sh zkSe ...   Up      0.0.0.0:2181->2181/tcp, 2888/tcp, 3888/tcp, 8080/tcp
    zoo2     /docker-entrypoint.sh zkSe ...   Up      0.0.0.0:2182->2181/tcp, 2888/tcp, 3888/tcp, 8080/tcp
    zoo3     /docker-entrypoint.sh zkSe ...   Up      0.0.0.0:2183->2181/tcp, 2888/tcp, 3888/tcp, 8080/tcp
    ```

    Alternatively, you should observe the same on Docker Desktop as well:

    ![DockerDesktop](https://raw.githubusercontent.com/Q-gabe/Dockerized-Multi-Broker-Kafka-ZK-Cluster/main/assets/dockerdesktop.png)


## **Stage 2** – Creating a new Topic

1.	Run the included bash script `create-topic.sh` to create a new topic: 
    ```
    ./create-topic.sh testTopic
    ```
    (You can name it whatever you like by changing testTopic)

    This bash script creates a topic with the specified name in the `kafka1` broker with a single partition, with the data replicated across all 3 brokers.

    You should receive a similar success message: `Created topic testTopic`.

    On the terminal where you first ran `docker-compose up`, you should see log entries similar to the following:
    ```
    kafka1    | [2020-10-22 02:38:09,064] INFO Creating topic testTopic with configuration {} and initial partition assignment HashMap(0 -> ArrayBuffer(1, 3, 2)) …
    …
    kafka3    | [2020-10-22 02:38:10,274] INFO [ReplicaFetcher replicaId=3, leaderId=1, fetcherId=0] Starting (kafka.server.ReplicaFetcherThread) …
    …
    kafka2    | [2020-10-22 02:38:10,519] INFO [ReplicaFetcher replicaId=2, leaderId=1, fetcherId=0] Starting (kafka.server.ReplicaFetcherThread) …
    ```

2.	Ensure that you have installed the kafkacat utility.
    
    (Remember to restart your terminal after installation to ensure the command kafkacat is recognized)

3.	Verify our topic creation in the kafka1 broker using the kafkacat utility: 
    ```
    kafkacat -L -b localhost:32001
    ```

    Which should return an output the metadata for the topics and information about the other 2 brokers in the cluster, similar to this:
    ```
    > kafkacat -L -b localhost:32001
    Metadata for all topics (from broker 1: localhost:32001/1):
     3 brokers:
      broker 2 at localhost:32002
      broker 3 at localhost:32003 (controller)
      broker 1 at localhost:32001
     1 topics:
      topic "testTopic" with 1 partitions:
        partition 0, leader 3, replicas: 3,2,1, isrs: 3,2,1
    ```
    As you can see from the last two lines, we successfully created a Topic named “`testTopic`” with a single partition with an index of `0` (`partition`), and the master node for this partition has the broker ID of `3` (`leader`). The topic is also replicated across brokers with IDs `3`, `2` and `1` (`leader`) and all the brokers are also up to date with the leader replica.


## **Stage 3** – Publishing and Consuming Messages from a Topic

1.	Use the kafkacat utility in Producer mode (-P) to publish messages to the topic you created:
    ```
    kafkacat -b localhost:32001 -t testTopic -P
    ```
    Type a random message or two and hit <kbd>Ctrl</kbd>+<kbd>D</kbd> to end the message transmission. Messages are newline separated. For instance:
    ```
    > kafkacat -b localhost:32001 -t testTopic -P
    42
    test test
    ```
    This publishes 2 messages with the content “`42`” and “`test test`” to the Topic “`test`” to the broker at `localhost:32001` (`kafka1`).

2.	Observe that the messages have been successfully published by running the kafkacat utility in Consumer mode (-C) to publish messages:
    ```
    kafkacat -b localhost:32001 -t testTopic -C
    ```
    Then, exit with <kbd>Ctrl</kbd>+<kbd>C</kbd>.

    You should see an output like:
    ```
    > kafkacat -b localhost:32001 -t testTopic -C
    42
    test test
    % Reached end of topic testTopic [0] at offset 2
    ^C
    ```


## **Stage 4** - Observing Fault-Tolerance (_Leader Partition & Controller Re-election_)

1.	Find the broker with the leader partition of the topic by using kafkacat:
    ```
    kafkacat -b localhost:32001 -L
    ```

    Which should return an output as we have seen previously:
    ```
    > kafkacat -L -b localhost:32001
    Metadata for all topics (from broker 1: localhost:32001/1):
     3 brokers:
      broker 2 at localhost:32002
      broker 3 at localhost:32003 (controller)
      broker 1 at localhost:32001
     1 topics:
      topic "testTopic" with 1 partitions:
        partition 0, leader 3, replicas: 3,2,1 isrs: 3,2,1
    ```

    As before, we can observe that the topic has a leader partition on broker with ID `1` (`kafka1`).

2.	Kill the container that the Broker with the leader partition is running in by running:
    ```
    docker kill kafka<BROKER_ID>
    ```
    (e.g. if `leader 3`, run ‘`docker kill kafka3`’)

    On the terminal where you first ran docker compose up, you should see log entries similar to the following:
    ```
    kafka3    | java.io.IOException: Connection to kafka1:9092 (id: 1 rack: null) failed. …
    kafka2    | java.io.IOException: Connection to kafka1:9092 (id: 1 rack: null) failed. …
    ```

3.	Wait for a maximum of 18 seconds (default Zookeeper timeout), and you should see logs similar to those below from the leader Zookeeper in the terminal where you first ran docker compose up:
    ```
    zoo3      | 2020-10-22 06:03:55,180 [myid:3] - INFO  [SessionTracker:ZooKeeperServer@610] - Expiring session 0x2000533ab850000, timeout of 18000ms exceeded
    zoo3      | 2020-10-22 06:03:55,196 [myid:3] - INFO  [RequestThrottler:QuorumZooKeeperServer@159] - Submitting global closeSession request for session 0x2000533ab850000
    ```

    At this stage, leader re-election for the topics happens internally within the Kafka cluster as the leader is declared to be unreachable by the Zookeeper ensemble. If the Broker that was killed happened to be the elected controller broker, controller re-election also happens here.

4.	Observe the re-election results by using kafkacat:
    ```
    kafkacat -b localhost:32001 -L
    ```
    (If you removed `kafka1`, use `localhost:32002` (`kafka2`'s external exposed port) or `localhost:32003` (`kafka3`'s external exposed port) instead.)

    Which should return an output similar to this:
    ```
    > kafkacat -L -b localhost:32001
    Metadata for all topics (from broker 1: localhost:32001/1):
     2 brokers:
      broker 2 at localhost:32002
      broker 1 at localhost:32001 (controller)
     1 topics:
      topic "testTopic" with 1 partitions:
        partition 0, leader 2, replicas: 3,2,1 isrs: 2,1
    ```

    We can see that kafka2 is now elected as the broker with the leader partition and kafka1 is elected as the controller. Also note that the replica in the disconnected kafka3 broker is no longer listed as in-sync with the leader partition (`isrs`).

5.	Repeat Stage 3 to see that publishing and consuming to the topic still works.
    
    Again, if you removed `kafka1`, use `localhost:32002` (`kafka2`'s external exposed port) or `localhost:32003` (`kafka3`'s external exposed port) instead for the kafkacat commands.

6.	Restore the removed broker by running:
    ```
    docker-compose up -d kafka<BROKER_ID>
    ```


## **Stage 5** - Observing Fault-Tolerance (_Zookeeper Leader Re-election_)

1.	Run the included bash script `show-zookeeper-modes.sh` to see the modes each of the Zookeeper Servers:
    ```
    ./show-zookeeper-modes.sh
    ```
    Which should return a similar output:
    ```
    > ./show-zookeeper-modes.sh
    Zookeeper Modes:
    Zoo1 -> Mode: follower
    Zoo2 -> Mode: follower
    Zoo3 -> Mode: leader
    ```
    Notice in this example, `zoo3` is the current leader in the Zookeeper ensemble.

2.	Kill the container that the leader Zookeeper is running in by running:
    ```
    docker kill <zoo1/2/3>
    ```
    (e.g. if `Zoo1 -> Mode: leader`, run ‘`docker kill zoo1`’)

    On the terminal where you first ran `docker-compose up`, you should see log entries similar to the following:

    _Other Zookeepers noticing lack of connection to killed Zookeeper:_
    ```
    zoo1      | 2020-10-22 07:29:16,821 [myid:1] - WARN  [QuorumPeer[myid=1](plain=0.0.0.0:2181)(secure=disabled):Follower@129] - Exception when following the leader
    …
    zoo2      | 2020-10-22 07:29:16,819 [myid:2] - WARN  [QuorumPeer[myid=2](plain=0.0.0.0:2181)(secure=disabled):Follower@129] - Exception when following the leader
    …
    ```

    _Zookeepers changing modes and initiating re-election:_
    ```                                                                                                  :
    zoo1      | 2020-10-22 07:29:16,971 [myid:1] - INFO  [QuorumPeer[myid=1](plain=0.0.0.0:2181)(secure=disabled):QuorumPeer@863] - Peer state changed: looking
    …
    zoo2      | 2020-10-22 07:29:17,018 [myid:2] - INFO  [QuorumPeer[myid=2](plain=0.0.0.0:2181)(secure=disabled):QuorumPeer@863] - Peer state changed: looking
    …
    zoo1      | 2020-10-22 07:29:17,018 [myid:1] - INFO  [QuorumPeer[myid=1](plain=0.0.0.0:2181)(secure=disabled):FastLeaderElection@944] - New election. My id = 1, proposed zxid=0x10000006e
    …
    zoo2      | 2020-10-22 07:29:17,061 [myid:2] - INFO  [QuorumPeer[myid=2](plain=0.0.0.0:2181)(secure=disabled):FastLeaderElection@944] - New election. My id = 2, proposed zxid=0x10000006e
    …
    ```
    	
    _Zookeepers ending session and changing states:_
    ```
    zoo1      | 2020-10-22 07:29:17,240 [myid:1] - WARN  [NIOWorkerThread-4:NIOServerCnxn@373] - Close of session 0x0
    …
    zoo2      | 2020-10-22 07:29:17,313 [myid:2] - WARN  [NIOWorkerThread-3:NIOServerCnxn@373] - Close of session 0x0
    …
    zoo1      | 2020-10-22 07:29:17,337 [myid:1] - INFO  [QuorumPeer[myid=1](plain=0.0.0.0:2181)(secure=disabled):QuorumPeer@1456] – FOLLOWING
    …
    zoo2      | 2020-10-22 07:29:17,338 [myid:2] - INFO  [QuorumPeer[myid=2](plain=0.0.0.0:2181)(secure=disabled):QuorumPeer@1468] - LEADING
    ```

    From the logs, you can see the entire process of re-election in this example, resulting in `zoo2` is elected as the new Zookeeper leader server.

    You may repeat **step 1** to confirm this result.

3.	Repeat **Stage 3** to see that publishing and consuming to the topic still works.


## **Stage 6** - Terminating and Clean-up

1.	Run the following command to stop and remove all containers:
    ```
    docker-compose down
    ```
    Note: It is crucial to remove all containers before re-attempting the entire setup process as Docker will recreate containers instead and can cause stale configurations to persist. 


## **Appendix** – Network Setup

For this setup, the official Zookeeper image is used for the Zookeeper servers and the wurstmeister/kafka image is used for the Kafka brokers.

### Zookeepers
Zookeepers are configured to run in replicated mode/quorum. Ports 2888 and 3888 are used to communicate between Zookeepers while port 2181 is used to listen for client connections. Port 2181 of each server is also published for accessibility to the external network on the host ports 2181, 2182 and 2183 for Zookeeper servers zoo1, zoo2 and zoo3 respectively.

### Kafka Brokers
Kafka brokers are configured to be fully connected to all Zookeeper servers on their client port. For inter-broker communication, Kafka brokers advertises and listens on an unpublished port 9092 (Note that communication happens internally so hostnames can be resolved). To communicate with the external network, the port 32001, 32002 and 32003 are mapped to external host ports.

### Network Topology
![Network Topology](https://raw.githubusercontent.com/Q-gabe/Dockerized-Multi-Broker-Kafka-ZK-Cluster/main/assets/NetworkDiagram.png)


## **Appendix** – Helpful Links

Kafka can be pretty confusing to get started with, especially when the difficulty of networking between Docker containers is included. Here are a few links that helped me a substantial bit:

*  Networking for Internal and External networking for Kafka Brokers in Docker:
   * [This incredible and visual blogpost by rmoff](https://rmoff.net/2018/08/02/kafka-listeners-explained/)
   * [wurstmeister’s own connectivity walkthrough](https://github.com/wurstmeister/kafka-docker/wiki/Connectivity)
*  [Replicated mode for Zookeeper servers](https://zookeeper.apache.org/doc/current/zookeeperStarted.html#sc_RunningReplicatedZooKeeper)
* [Using kafkacat to produce and consume messages](https://docs.confluent.io/current/app-development/kafkacat-usage.html)
