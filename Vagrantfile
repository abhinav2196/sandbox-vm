# Secure Signing VM
Vagrant.configure("2") do |config|
  
  # Load config
  require 'yaml'
  cfg_file = File.join(File.dirname(__FILE__), 'config.yaml')
  cfg = File.exist?(cfg_file) ? YAML.load_file(cfg_file) : {}
  
  NETWORK_ENABLED = cfg.fetch('network_enabled', true)
  VM_MEMORY = "2048"
  VM_CPUS = 2

  # Platform detection
  is_arm = `uname -m`.strip == 'arm64'
  provider = ENV['VAGRANT_DEFAULT_PROVIDER'] || 'virtualbox'
  
  # Box selection
  config.vm.box = (provider == 'qemu' && is_arm) ? "perk/ubuntu-2204-arm64" : "ubuntu/jammy64"
  config.vm.hostname = "signing-vm"
  
  # Disable shared folders (security)
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.synced_folder ".", "/vagrant_config", disabled: false, type: "rsync", 
    rsync__include: ["config.yaml", "scripts/"]
  
  # Provider configs
  config.vm.provider "virtualbox" do |vb|
    vb.memory = VM_MEMORY
    vb.cpus = VM_CPUS
    vb.gui = true
    vb.name = "signing-vm"
    vb.customize ["modifyvm", :id, "--clipboard", "disabled"]
    vb.customize ["modifyvm", :id, "--draganddrop", "disabled"]
  end

  config.vm.provider "qemu" do |qe|
    qe.memory = VM_MEMORY
    qe.cpus = VM_CPUS
    qe.arch = "aarch64" if is_arm
  end

  config.vm.provider "vmware_desktop" do |vm|
    vm.memory = VM_MEMORY
    vm.cpus = VM_CPUS
    vm.gui = true
  end

  config.vm.provider "parallels" do |prl|
    prl.memory = VM_MEMORY.to_i
    prl.cpus = VM_CPUS
    prl.customize ["set", :id, "--shared-clipboard", "off"]
  end

  # Provision: base system
  config.vm.provision "shell", path: "scripts/provision.sh"
  
  # Provision: network
  network_action = NETWORK_ENABLED ? "enable" : "disable"
  config.vm.provision "shell", inline: "bash /vagrant_config/scripts/network.sh #{network_action}"
  
  # Post-up message
  config.vm.post_up_message = <<~MSG
    ══════════════════════════════════════════
    Signing VM Ready
    ══════════════════════════════════════════
    
    Login: security / changeme (change this!)
    Network: #{NETWORK_ENABLED ? 'Enabled (DNS/HTTP/HTTPS)' : 'Disabled'}
    
    To fetch secrets:
      sudo /vagrant_config/scripts/secrets.sh
    
    Commands:
      vagrant halt     - Stop VM
      vagrant destroy  - Delete VM + all secrets
    ══════════════════════════════════════════
  MSG
end
