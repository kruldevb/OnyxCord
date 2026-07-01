#!/usr/bin/env ruby
require 'fileutils'

IGNORED_ENTRIES = ['.github', '.git'].freeze

EXAMPLE_TREE = <<~TREE
meu_projeto/
├── app/
│   ├── __init__.py
│   ├── main.py              # Ponto de entrada
│   │
│   ├── api/
│   │   ├── __init__.py
│   │   ├── routes.py
│   │   ├── auth.py
│   │   └── users.py
│   │
│   ├── controllers/
│   │   ├── auth_controller.py
│   │   └── user_controller.py
│   │
│   ├── services/
│   │   ├── auth_service.py
│   │   ├── user_service.py
│   │   └── email_service.py
│   │
│   ├── models/
│   │   ├── user.py
│   │   └── base.py
│   │
│   ├── repositories/
│   │   └── user_repository.py
│   │
│   ├── database/
│   │   ├── connection.py
│   │   ├── migrations/
│   │   └── seed.py
│   │
│   ├── middleware/
│   │   ├── auth.py
│   │   └── logger.py
│   │
│   ├── utils/
│   │   ├── helpers.py
│   │   ├── validator.py
│   │   └── jwt.py
│   │
│   ├── config/
│   │   ├── settings.py
│   │   └── logging.py
│   │
│   ├── templates/           # Caso utilize HTML
│   │
│   ├── static/
│   │   ├── css/
│   │   ├── js/
│   │   └── images/
│   │
│   └── schemas/             # Validação (Pydantic)
│       ├── user.py
│       └── auth.py
│
├── tests/
│   ├── test_auth.py
│   ├── test_users.py
│   └── conftest.py
│
├── scripts/
│   ├── create_admin.py
│   └── backup.py
│
├── docs/
│
├── .env
├── .env.example
├── .gitignore
├── requirements.txt
├── pyproject.toml
├── README.md
└── run.py
TREE


def build_tree(root_path, prefix = '')
  entries = Dir.children(root_path).sort
  lines = []
  visible_entries = entries.reject { |entry| IGNORED_ENTRIES.include?(entry) }

  visible_entries.each_with_index do |entry, index|
    full_path = File.join(root_path, entry)
    is_last = index == visible_entries.length - 1
    connector = is_last ? '└── ' : '├── '
    lines << "#{prefix}#{connector}#{entry}"

    if File.directory?(full_path) && !File.symlink?(full_path)
      child_prefix = prefix + (is_last ? '    ' : '│   ')
      lines.concat(build_tree(full_path, child_prefix))
    end
  end

  lines
end

if ARGV.include?('--example')
  output_file = ARGV[1] || File.expand_path('estrutura.txt', Dir.pwd)
  File.write(output_file, EXAMPLE_TREE)
  puts "Estrutura de exemplo salva em #{output_file}"
  exit 0
end

source_dir = ARGV[0] || Dir.pwd
output_file = ARGV[1] || File.expand_path('estrutura.txt', Dir.pwd)

unless Dir.exist?(source_dir)
  warn "Diretório não encontrado: #{source_dir}"
  exit 1
end

root_name = File.basename(File.expand_path(source_dir))
tree_lines = ["#{root_name}/"] + build_tree(source_dir)
File.write(output_file, tree_lines.join("\n") + "\n")
puts "Estrutura salva em #{output_file}"
