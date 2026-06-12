#!/usr/bin/env python3
"""
Script para criar um backup ZIP do projeto INFILTRAITOR
Exclui arquivos grandes (assets) e diretórios desnecessários
"""

import os
import zipfile
from pathlib import Path

# Diretório raiz do projeto
PROJECT_DIR = Path(__file__).parent.absolute()
BACKUP_FILE = PROJECT_DIR / "BACKUP.ZIP"

# Pastas e arquivos a serem excluídos
EXCLUDE_DIRS = {
    "ASSETS",          # Arquivos gráficos grandes
    "ARCHIVE",         # Backup antigo
    "Concept",         # Imagens de conceito (69 MB)
    "REFERENCES",      # Imagens de referência (1.3 MB)
    "export",          # Exportações do projeto
    ".git",            # Repositório git
    ".godot",          # Cache do Godot
    ".vscode",         # Configurações VS Code
    "__pycache__",     # Cache Python
    ".pytest_cache",
    "node_modules",
}

EXCLUDE_FILES = {
    ".DS_Store",
    "BACKUP.ZIP",  # Não incluir a si mesmo se já existir
}

EXCLUDE_EXTENSIONS = {
    ".pyc",
    ".pyo",
    ".pyd",
    ".so",
}


def should_exclude(path: Path, relative_to: Path) -> bool:
    """Determina se um arquivo/diretório deve ser excluído"""
    rel_path = path.relative_to(relative_to)
    
    # Verificar se é arquivo a excluir
    if path.is_file():
        if path.name in EXCLUDE_FILES:
            return True
        if path.suffix in EXCLUDE_EXTENSIONS:
            return True
    
    # Verificar se está dentro de diretório a excluir
    for part in rel_path.parts:
        if part in EXCLUDE_DIRS:
            return True
    
    return False


def create_backup(output_path: Path = None):
    """Cria o arquivo ZIP de backup"""
    if output_path is None:
        output_path = BACKUP_FILE
    
    # Remover arquivo existente
    if output_path.exists():
        output_path.unlink()
        print(f"✓ Arquivo anterior removido: {output_path.name}")
    
    # Criar arquivo ZIP
    with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as zipf:
        file_count = 0
        total_size = 0
        
        for file_path in PROJECT_DIR.rglob("*"):
            # Pular arquivos/diretórios a excluir
            if should_exclude(file_path, PROJECT_DIR):
                continue
            
            # Pular diretórios vazios (apenas arquivos)
            if file_path.is_file():
                rel_path = file_path.relative_to(PROJECT_DIR)
                arcname = f"INFILTRAITOR/{rel_path}"
                
                try:
                    zipf.write(file_path, arcname=arcname)
                    file_count += 1
                    total_size += file_path.stat().st_size
                except Exception as e:
                    print(f"⚠ Erro ao incluir {file_path}: {e}")
    
    # Exibir resumo
    size_mb = total_size / (1024 * 1024)
    print(f"\n✓ Backup criado com sucesso!")
    print(f"  Arquivo: {output_path.name}")
    print(f"  Localização: {output_path.parent}")
    print(f"  Arquivos incluídos: {file_count}")
    print(f"  Tamanho: {size_mb:.2f} MB")
    print(f"\nPastas excluídas: {', '.join(sorted(EXCLUDE_DIRS))}")


if __name__ == "__main__":
    create_backup()
