{ config, pkgs, ... }:

with pkgs.lib;

let

  cfg = config.services.ircdHybrid;
  
  ircdService = pkgs.stdenv.mkDerivation rec {
    name = "ircd-hybrid-service";
    scripts = [ "=>/bin" ./control.in ];
    substFiles = [ "=>/conf" ./ircd.conf ];
    inherit (pkgs) ircdHybrid coreutils su iproute gnugrep procps;

    gw6cEnabled = if config.services.gw6c.enable && config.services.gw6c.autorun then "true" else "false";

    inherit (cfg) serverName sid description adminEmail
            extraPort;

    cryptoSettings = 
      (optionalString (cfg.rsaKey != null) "rsa_private_key_file = \"${cfg.rsaKey}\";\n") +
      (optionalString (cfg.certificate != null) "ssl_certificate_file = \"${cfg.certificate}\";\n");

    extraListen = map (ip: "host = \""+ip+"\";\nport = 6665 .. 6669, "+extraPort+"; ") cfg.extraIPs;

    builder = ./builder.sh;
  };

  startingDependency = if config.services.gw6c.enable then "gw6c" else "network-interfaces";

in

{

  ###### interface

  options = {
  
    services.ircdHybrid = {

      enable = mkOption {
        default = false;
        description = "
          Enable IRCD.
        ";
      };

      serverName = mkOption {
        default = "hades.arpa";
        description = "
          IRCD server name.
        ";
      };

      sid = mkOption {
        default = "0NL";
        description = "
          IRCD server unique ID in a net of servers.
        ";
      };

      description = mkOption {
        default = "Hybrid-7 IRC server.";
        description = "
          IRCD server description.
        ";
      };

      rsaKey = mkOption {
        default = null;
        example = /root/certificates/irc.key;
        description = "
          IRCD server RSA key. 
        ";
      };

      certificate = mkOption {
        default = null;
        example = /root/certificates/irc.pem;
        description = "
          IRCD server SSL certificate. There are some limitations - read manual.
        ";
      };

      adminEmail = mkOption {
        default = "<bit-bucket@example.com>";
        example = "<name@domain.tld>";
        description = "
          IRCD server administrator e-mail. 
        ";
      };

      extraIPs = mkOption {
        default = [];
        example = ["127.0.0.1"];
        description = "
          Extra IP's to bind.
        ";
      };

      extraPort = mkOption {
        default = "7117";
        description = "
          Extra port to avoid filtering.
        ";
      };

    };

  };


  ###### implementation

  config = mkIf config.services.ircdHybrid.enable {

    users.extraUsers = singleton
      { name = "ircd"; 
        description = "IRCD owner";
      };

    users.extraGroups = singleton
      { name = "ircd"; };

    jobs.ircd_hybrid =
      { name = "ircd-hybrid";

        description = "IRCD Hybrid server";

        startOn = "started ${startingDependency}";
        stopOn = "stopping ${startingDependency}";

        exec = "${ircdService}/bin/control start";
      };

  };

}