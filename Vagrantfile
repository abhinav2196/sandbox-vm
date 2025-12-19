# Secure Signing VM
Vagrant.configure("2") do |config|
  
  # Load config
  require 'yaml'
  cfg_file = File.join(File.dirname(__FILE__), 'config.yaml')
  cfg = File.exist?(cfg_file) ? YAML.load_file(cfg_file) : {}
  
  NETWORK_ENABLED = cfg.fetch('network_enabled', true)
  GUI_ENABLED = cfg.fetch('gui_enabled', false)
  DEFAULT_SSH_PORT = cfg.fetch('ssh_port', 50223)
  VM_MEMORY = cfg.fetch('vm_memory', 6144).to_s  # 6GB RAM
  VM_CPUS = cfg.fetch('vm_cpus', 6)              # 6 cores
  
  # Platform detection
  is_arm = RUBY_PLATFORM.include?('arm64') || `uname -m`.strip == 'arm64'
  provider = is_arm ? 'qemu' : 'virtualbox'
  env_ssh_port = ENV['VAGRANT_SSH_PORT']
  ssh_port = if env_ssh_port && !env_ssh_port.empty?
               env_ssh_port.to_i
             else
               DEFAULT_SSH_PORT
             end
  
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
  
  # Synced folders (disabled for pre-built boxes - scripts already baked in)
  config.vm.synced_folder ".", "/vagrant", disabled: true
  unless use_prebuilt
    config.vm.synced_folder ".", "/vagrant_config", type: "rsync",
      rsync__include: ["config.yaml", "scripts/"]
  end
  
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
