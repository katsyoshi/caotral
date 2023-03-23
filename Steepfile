D = Steep::Diagnostic
#
target :lib do
  signature "sig"
  check "lib"                       # Directory name
  configure_code_diagnostics(D::Ruby.strict)       # `strict` diagnostics setting
  configure_code_diagnostics(D::Ruby.lenient)      # `lenient` diagnostics setting
  configure_code_diagnostics do |hash|             # You can setup everything yourself
    hash[D::Ruby::NoMethod] = :information
    hash[D::Ruby::UnknownConstant] = :information
  end
end
