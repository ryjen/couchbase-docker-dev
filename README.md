

The development environment creates 3 containers:

#### Couchbase Server/Cluster

The main server node with a cluster initialized.  Enabled services are `data, index and query`.

#### Couchbase Server/Node

A secondary server node added to the cluster.  Enabled services are `fts, eventing and analytics`.

#### Sync Gateway

A sync gateway to perform services for clients


#### Using

Hopefully can just run `./control.sh` in the folder.  Report an issue if not.

Once the containers boot, open `http://localhost:8091` and use the credentials `Administrator:password`




