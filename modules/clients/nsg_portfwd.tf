// BGP Peer
resource "netskopebwan_gateway_port_forward" "client" {
  for_each        = toset(var.clients.ports)
  gateway_id      = var.primary_gw_data.id
  name            = join("-", ["client", each.key])
  bi_directional  = false
  lan_ip          = google_compute_address.client.address
  lan_port        = each.key
  public_ip       = var.primary_gw_data.public_ips[keys(var.primary_gw_data.public_ips)[0]].address
  public_port     = each.key
  up_link_if_name = upper(keys(var.primary_gw_data.public_ips)[0])
}