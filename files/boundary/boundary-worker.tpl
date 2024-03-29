disable_mlock = true
hcp_boundary_cluster_id = "${boundary_cluster_id}"

listener "tcp" {
    address = "${private_ip}:9202"
    purpose = "proxy"
    tls_disable = true
}

listener "tcp" {
    address = "${private_ip}:9203"
    purpose = "ops"
    tls_disable = true
}
  
worker {
    # Name attr must be unique
    public_addr = "${public_ip}"
    auth_storage_path = "/etc/boundary/worker1"
    tags {
        type = ["worker", "dev"]
    }
}
