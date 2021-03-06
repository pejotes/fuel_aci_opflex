#Class cisco_aci::opflex_ml2
class cisco_aci::opflex_ml2 (
    $ha_prefix                          = '',
    $role                               = 'compute',
    $use_lldp                           = true,
    $apic_system_id                     = '',
    $apic_hosts                         = '10.0.0.1',
    $apic_username                      = 'admin',
    $apic_password                      = 'password',
    $static_config                      = '',
    $additional_config                  = '',
    $service_plugins                    = 'cisco_apic_l3,neutron.services.metering.metering_plugin.MeteringPlugin',
    $mechanism_drivers                  = 'cisco_apic_ml2',
    $admin_username                     = 'admin',
    $admin_password                     = 'admin',
    $admin_tenant                       = 'admin',
    $ext_net_enable                     = false,
    $ext_net_name                       = 'ext',
    $ext_net_switch                     = '101',
    $ext_net_port                       = '1/1',
    $ext_net_subnet                     = '10.0.0.0/24',
    $ext_net_gateway                    = '10.0.0.1',
    $db_connection                      = '',
    $ext_net_config                     = false,
    $pre_existing_vpc                   = true,
    $pre_existing_l3_context            = true,
    $shared_context_name                = '',
    $apic_external_network              = '',
    $pre_existing_external_network_on   = '',
    $external_epg                       = '',
    $opflex_interface                   = '',
    $apic_infra_vlan                    = '',
    $opflex_encap_type                  = 'vlan',
    $opflex_peer_ip                     = '',
    $opflex_remote_ip                   = '',
    $br_to_patch                        = '',
){
    include 'apic::params'
    include 'apic::api'

    if $use_lldp {
        class {'apic::svc_agent':
            role    => $role
        }
    }

    if ($ext_net_enable == true) {
        $apic_external_network = $ext_net_name
    }

    case $role {
        /controller/: {
            if $use_lldp {
                include 'apic::svc_agent'
            }else {
                package { 'apic_ml2_package':
                    ensure => 'present',
                    name   => $::apic::params::package_neutron_ml2_driver_apic,
                }
            }
            include 'neutron::services::apic_server'
            include "neutron::services::${ha_prefix}agents"

            class {'neutron::config_auth':
                admin_username => $admin_username,
                admin_password => $admin_password,
                admin_tenant   => $admin_tenant,
            }
            if ($role == 'primary-controller' and $ext_net_enable == true){
                class {'neutron::network':
                    tenant_name     => $admin_tenant,
                    ext_net_name    => $ext_net_name,
                    ext_net_subnet  => $ext_net_subnet,
                    ext_net_gateway => $ext_net_gateway,
                }

            }
        }
        'compute': {
            class {'neutron::services::ovs_agent':
                enabled        => false,
                manage_service => true,
            }
        }
        default: {
        }
    }

    Neutron_config <| |> ~> Service <| title == 'neutron-server' |>
    Neutron_plugin_ml2 <| |> ~> Service <| title == 'neutron-server' |>
    Neutron_plugin_ml2_cisco <| |> ~> Service <| title == 'neutron-server' |>
    Neutron_dhcp_agent_config <| |> ~> Service <| title == 'neutron-dhcp-agent' |>

    #KVR: comment out next 3 lines, dont need neutron-ovs-agent
    #Neutron_config <| |> ~> Service <| title == 'neutron-ovs-agent' |>
    #Neutron_plugin_ml2 <| |> ~> Service <| title == 'neutron-ovs-agent' |>
    #Neutron_plugin_ml2_cisco <| |> ~> Service <| title == 'neutron-ovs-agent' |>
    File <| title == 'neutron_initd' |> ~> Service <| title == 'neutron-server' |>

    if $use_lldp {
        include 'lldp'
        include 'apic::host_agent'

    }

    case $role {
        /controller/: {
            class {'neutron::config':
                service_plugins   => $service_plugins,
                mechanism_drivers => $mechanism_drivers,
                db_connection     => $db_connection,
                opflex_encap_type => $opflex_encap_type,
            }
            
            class {'neutron::config_dhcp':}
        
            class {'neutron::config_apic':
                apic_system_id                     => $apic_system_id,
                apic_hosts                         => $apic_hosts,
                apic_username                      => $apic_username,
                apic_password                      => $apic_password,
                static_config                      => $static_config,
                additional_config                  => $additional_config,
                ext_net_enable                     => $ext_net_enable,
                ext_net_name                       => $ext_net_name,
                ext_net_switch                     => $ext_net_switch,
                ext_net_port                       => $ext_net_port,
                ext_net_subnet                     => $ext_net_subnet,
                ext_net_gateway                    => $ext_net_gateway,
                ext_net_config                     => $ext_net_config,
                pre_existing_vpc                   => $pre_existing_vpc,
                pre_existing_l3_context            => $pre_existing_l3_context,
                shared_context_name                => $shared_context_name,
                apic_external_network              => $apic_external_network,
                pre_existing_external_network_on   => $pre_existing_external_network_on,
                external_epg                       => $external_epg,
                gbp                                => false,
            }
        }
        default: {
        }
    }

    class {'opflex::opflex_agent':
        opflex_ovs_bridge_name             => 'br-int',
        opflex_uplink_iface                => $opflex_interface,
        opflex_uplink_vlan                 => $apic_infra_vlan,
        opflex_apic_domain_name            => $apic_system_id,
        opflex_encap_type                  => $opflex_encap_type,
        opflex_peer_ip                     => $opflex_peer_ip,
        opflex_remote_ip                   => $opflex_remote_ip,
        br_to_patch                        => $br_to_patch,
    }
}
