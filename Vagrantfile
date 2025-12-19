# Secure Signing VM
Vagrant.configure("2") do |config|
  
  # Load config
  require 'yaml'
  cfg_file = File.join(File.dirname(__FILE__), 'config.yaml')
  cfg = File.exist?(cfg_file) ? YAML.load_file(cfg_file) : {}
  
  NETWORK_ENABLED = cfg.fetch('network_enabled', true)
  GUI_ENABLED = cfg.fetch('gui_enabled', false)
  VM_MEMORY = "2048"
  VM_CPUS = 2
  
  # Platform detection
  is_arm = RUBY_PLATFORM.include?('arm64') || `uname -m`.strip == 'arm64'
  provider = is_arm ? 'qemu' : 'virtualbox'
  ssh_port = (ENV['VAGRANT_SSH_PORT'] && !ENV['VAGRANT_SSH_PORT'].empty?) ? ENV['VAGRANT_SSH_PORT'].to_i : 50222
  
  # Box selection: use pre-built if available (via env var), else base box
  use_prebuilt = ENV['USE_PREBUILT'] == '1'
  
  if use_prebuilt
    config.vm.box = "signing-vm-base"
  elsif provider == 'qemu'
    config.vm.box = "perk/ubuntu-2204-arm64"
  else
    config.vm.box = "ubuntu/jammy64"
  end
  
  config.vm.hostname = "signing-vm"
  
  # Synced folders
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.synced_folder ".", "/vagrant_config", type: "rsync",
    rsync__include: ["config.yaml", "scripts/"]
  
  # Provider configs
  config.vm.provider "virtualbox" do |vb|
    vb.memory = VM_MEMORY
    vb.cpus = VM_CPUS
    vb.gui = true
    vb.name = "signing-vm"
    vb.customize ["modifyvm", :id, "--clipboard", "disabled"]
  end

  config.vm.provider "qemu" do |qe|
    qe.memory = VM_MEMORY
    qe.cpus = VM_CPUS
    qe.arch = "aarch64" if is_arm
    # Avoid common 50022 collisions. Override with: VAGRANT_SSH_PORT=XXXXX
    qe.ssh_port = ssh_port
  end

  # Provisioning (skipped if using pre-built box)
  unless use_prebuilt
    gui_flag = GUI_ENABLED ? "gui" : "nogui"
    config.vm.provision "shell", path: "scripts/provision.sh", args: [gui_flag]
    network_action = NETWORK_ENABLED ? "enable" : "disable"
    config.vm.provision "shell", inline: "bash /vagrant_config/scripts/network.sh #{network_action}"
    # Hardening runs last (after all provisioners that need sudo)
    config.vm.provision "shell", inline: "bash /usr/local/sbin/harden.sh"
  end
  
  vnc_msg = GUI_ENABLED ? "\n    VNC:            vagrant ssh -- -L 5901:localhost:5901\n                    Then: open vnc://localhost:5901 (pw: changeme)" : ""
  
  config.vm.post_up_message = <<~MSG
    ══════════════════════════════════════════
    Signing VM Ready
    ══════════════════════════════════════════
    
    Login: security / changeme
    Network: #{NETWORK_ENABLED ? 'Enabled' : 'Disabled'}
    GUI: #{GUI_ENABLED ? 'Enabled (VNC on :5901)' : 'Disabled'}
    SSH Port: #{ssh_port} (host) → 22 (guest)
    
    Fetch secrets:  sudo /vagrant_config/scripts/secrets.sh#{vnc_msg}
    SSH:            vagrant ssh
    Stop:           vagrant halt
    Destroy:        vagrant destroy
    ══════════════════════════════════════════
  MSG
end
