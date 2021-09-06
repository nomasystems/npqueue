# Overview

npqueue is a library application that implements a simple and fast FIFO queue divided in partitions.

## Architecture

There is a gen_server por each queue. Each queue is divided in partitions which have their own gen_server and their own
consumer processes. There is no guaranteed ordering at queue level but there is at partition level if you setup only 1 
consumer per partition. So if two items are sent to the same partition at a particular order then they will be consumed 
at the same order only if the value of ConsumerCount configured in npqueue:start_link is 1.
We encourage to configure a big number of partitions as this will avoid the single process bottleneck and a fairly
amount of consumers per partition to avoid a partition getting stucked due to some items of the partition taking
more time to consume than others.

## Environment
No special configuration parameters are required by the application.
