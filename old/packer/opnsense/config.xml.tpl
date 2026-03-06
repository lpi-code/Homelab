<?xml version="1.0"?>
<!-- OPNsense configuration template - rendered by Packer shell-local provisioner -->
<!-- Variables substituted: LAN_IP, LAN_PREFIX -->
<opnsense>
  <theme>opnsense</theme>
  <sysctl>
    <item>
      <descr>Increase UFS read-ahead speeds to match modern disk speeds</descr>
      <tunable>vfs.read_max</tunable>
      <value>default</value>
    </item>
    <item>
      <descr>Set the ephemeral port range to be lower.</descr>
      <tunable>net.inet.ip.portrange.first</tunable>
      <value>default</value>
    </item>
    <item>
      <descr>Drop packets to closed TCP ports without returning a RST</descr>
      <tunable>net.inet.tcp.blackhole</tunable>
      <value>default</value>
    </item>
    <item>
      <descr>Do not send ICMP port unreachable messages for closed UDP ports</descr>
      <tunable>net.inet.udp.blackhole</tunable>
      <value>default</value>
    </item>
    <item>
      <descr>Randomize the ID field in IP packets (default is 1: sequential)</descr>
      <tunable>net.inet.ip.random_id</tunable>
      <value>default</value>
    </item>
  </sysctl>
  <system>
    <optimization>normal</optimization>
    <hostname>opnsense</hostname>
    <domain>homelab.local</domain>
    <dnsallowoverride>1</dnsallowoverride>
    <group>
      <name>admins</name>
      <description>System Administrators</description>
      <scope>system</scope>
      <gid>1999</gid>
      <member>0</member>
      <priv>page-all</priv>
    </group>
    <user>
      <name>root</name>
      <descr>System Administrator</descr>
      <scope>system</scope>
      <groupname>admins</groupname>
      <!-- Password hash is set by OPNsense installer - left empty here, installer sets it -->
      <password>$2y$10$YRVoF4SgskIsrXOvOQjjeureEnF19yHNkEB/4XDs5.7Be5T2DVezK</password>
      <uid>0</uid>
    </user>
    <nextuid>2000</nextuid>
    <nextgid>2000</nextgid>
    <timezone>UTC</timezone>
    <timeservers>0.opnsense.pool.ntp.org 1.opnsense.pool.ntp.org</timeservers>
    <webgui>
      <protocol>https</protocol>
      <ssl-certref>webgui-cert</ssl-certref>
    </webgui>
    <disablenatreflection>yes</disablenatreflection>
    <usevirtualterminal>1</usevirtualterminal>
    <disableconsolemenu/>
    <disablevlanhwfilter>1</disablevlanhwfilter>
    <disablechecksumoffloading>1</disablechecksumoffloading>
    <disablesegmentationoffloading>1</disablesegmentationoffloading>
    <disablelargereceiveoffloading>1</disablelargereceiveoffloading>
    <ipv6allow/>
    <powerd_ac_mode>hadp</powerd_ac_mode>
    <powerd_battery_mode>hadp</powerd_battery_mode>
    <powerd_normal_mode>hadp</powerd_normal_mode>
    <bogons>
      <interval>monthly</interval>
    </bogons>
    <pf_share_forward>1</pf_share_forward>
    <lb_use_sticky>1</lb_use_sticky>
    <ssh>
      <group>admins</group>
      <enabled>enabled</enabled>
      <permitrootlogin>1</permitrootlogin>
    </ssh>
    <rrdbackup>-1</rrdbackup>
    <netflowbackup>-1</netflowbackup>
    <firmware>
      <mirror>default</mirror>
      <flavour>default</flavour>
    </firmware>
  </system>
  <interfaces>
    <wan>
      <enable>1</enable>
      <if>vtnet0</if>
      <ipaddr>dhcp</ipaddr>
      <ipaddrv6>dhcp6</ipaddrv6>
      <dhcphostname/>
      <media/>
      <mediaopt/>
      <blockbogons>0</blockbogons>
      <blockpriv>0</blockpriv>
      <descr>WAN</descr>
    </wan>
    <lan>
      <enable>1</enable>
      <if>vtnet1</if>
      <ipaddr>${LAN_IP}</ipaddr>
      <subnet>${LAN_PREFIX}</subnet>
      <media/>
      <mediaopt/>
      <descr>LAN</descr>
      <ipaddrv6>track6</ipaddrv6>
      <subnetv6>64</subnetv6>
      <track6-interface>wan</track6-interface>
      <track6-prefix-id>0</track6-prefix-id>
    </lan>
  </interfaces>
  <dhcpd>
    <lan>
      <enable>1</enable>
      <range>
        <from>10.10.0.100</from>
        <to>10.10.0.199</to>
      </range>
    </lan>
  </dhcpd>
  <unbound>
    <enable>1</enable>
    <dnssec>1</dnssec>
    <active_interface/>
    <outgoing_interface/>
    <custom_options/>
    <hideidentity>0</hideidentity>
    <hideversion>0</hideversion>
    <dnssecstripped>1</dnssecstripped>
  </unbound>
  <snmpd>
    <syslocation/>
    <syscontact/>
    <rocommunity>public</rocommunity>
  </snmpd>
  <syslog>
    <filterdescriptions>1</filterdescriptions>
  </syslog>
  <nat>
    <outbound>
      <mode>automatic</mode>
    </outbound>
  </nat>
  <filter>
    <rule>
      <type>pass</type>
      <interface>lan</interface>
      <ipprotocol>inet</ipprotocol>
      <statetype>keep state</statetype>
      <direction>in</direction>
      <quick>1</quick>
      <source>
        <network>lan</network>
      </source>
      <destination>
        <any/>
      </destination>
      <descr>Allow LAN to any</descr>
    </rule>
    <rule>
      <type>block</type>
      <interface>wan</interface>
      <ipprotocol>inet</ipprotocol>
      <statetype>keep state</statetype>
      <direction>in</direction>
      <quick>1</quick>
      <source>
        <any/>
      </source>
      <destination>
        <any/>
      </destination>
      <descr>Block inbound WAN</descr>
    </rule>
  </filter>
  <rrd>
    <enable/>
  </rrd>
  <load_balancer>
    <monitor_type>
      <name>ICMP</name>
      <descr>ICMP</descr>
      <type>icmp</type>
      <options/>
    </monitor_type>
    <monitor_type>
      <name>TCP</name>
      <descr>Generic TCP</descr>
      <type>tcp</type>
      <options/>
    </monitor_type>
  </load_balancer>
  <widgets>
    <sequence>system_information-container:00000000-col3:show,interfaces-container:00000001-col4:show,graphstats-container:00000002-col4:show</sequence>
  </widgets>
  <revision>
    <username>root@console</username>
    <time>1700000000</time>
    <description>Initial Packer-deployed configuration</description>
  </revision>
  <OPNsense>
    <captiveportal version="1.0.0">
      <zones/>
      <templates/>
    </captiveportal>
    <cron version="1.0.2">
      <jobs/>
    </cron>
    <IDS version="1.0.8">
      <rules/>
      <policies/>
      <userDefinedRules/>
      <files/>
      <fileTags/>
      <options>
        <syslog_eve_enabled>0</syslog_eve_enabled>
        <syslog_alerts_enabled>0</syslog_alerts_enabled>
        <syslog_log_all>0</syslog_log_all>
        <default_packet_size/>
        <UpdateCron/>
        <AlertLogrotate>W0D23</AlertLogrotate>
        <AlertSaveLogs>4</AlertSaveLogs>
        <MPMAlgo/>
        <detect>
          <Profile/>
          <toclient_groups/>
          <toserver_groups/>
        </detect>
        <scheduleIntervals/>
      </options>
    </IDS>
    <proxy version="1.0.5">
      <forward>
        <enabled>0</enabled>
      </forward>
    </proxy>
    <Firewall>
      <Lvtemplate version="0.0.1">
        <templates/>
      </Lvtemplate>
      <Alias version="1.0.1">
        <aliases/>
      </Alias>
      <Category version="1.0.0">
        <categories/>
      </Category>
    </Firewall>
    <Netflow version="1.0.1">
      <capture>
        <interfaces/>
        <egress_only/>
        <version>v9</version>
        <targets/>
      </capture>
      <collect>
        <enable>0</enable>
      </collect>
      <activeTimeout>1800</activeTimeout>
      <inactiveTimeout>15</inactiveTimeout>
    </Netflow>
    <NodeExporter version="0.0.1">
      <enabled>0</enabled>
    </NodeExporter>
    <TrafficShaper version="1.0.3">
      <pipes/>
      <queues/>
      <rules/>
    </TrafficShaper>
  </OPNsense>
</opnsense>
