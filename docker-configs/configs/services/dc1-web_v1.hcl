service {
  name = "web"
  id = "web-v1"
  address = "10.5.0.100"
  port = 9090

  connect {
    sidecar_service {
      port = 20000

      check {
        name = "Connect Envoy Sidecar"
        tcp = "10.5.0.100:20000"
        interval ="10s"
      }

      proxy {
        upstreams {
            destination_name = "web-upstream"
            local_bind_address = "127.0.0.1"
            local_bind_port = 9091
        }
        // upstreams {
        //     destination_name = "web-chunky"
        //     destination_peer = "dc2-chunky"
        //     local_bind_address = "127.0.0.1"
        //     local_bind_port = 9092
        // }
      }
    }
  }
}

//  comment out peers