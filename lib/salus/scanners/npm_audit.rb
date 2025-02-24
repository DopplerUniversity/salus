require 'json'
require 'salus/scanners/node_audit'

# NPM Audit scanner integration. Flags known malicious or vulnerable
# dependencies in javascript projects.
# https://medium.com/npm-inc/npm-acquires-lift-security-258e257ef639

module Salus::Scanners
  class NPMAudit < NodeAudit
    AUDIT_COMMAND = 'pnpm audit --json'.freeze

    def should_run?
      true
    end

    def version
      shell_return = run_shell('pnpm --version')
      # stdout looks like "6.14.8\n"
      shell_return.stdout&.strip
    end

    def self.supported_languages
      ['javascript']
    end

    private

    def audit_command_with_options
      command = AUDIT_COMMAND
      command += " --production" if @config["production"] == true
      command
    end

    def scan_for_cves(chdir: File.expand_path(@repository&.path_to_repo))
      raw = run_shell(audit_command_with_options).stdout
      json = JSON.parse(raw, symbolize_names: true)

      if json.key?(:error)
        code = json[:error][:code] || '<none>'
        summary = json[:error][:summary] || '<none>'

        message =
          "`#{audit_command_with_options}` failed unexpectedly (error code #{code}):\n" \
          "```\n#{summary}\n```"

        raise message
      end

      report_stdout(json)

      json.fetch(:advisories).values
    end
  end
end
