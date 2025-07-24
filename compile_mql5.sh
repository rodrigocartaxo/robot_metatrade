#!/bin/bash

# Script para compilar arquivos MQL5
# Uso: ./compile_mql5.sh [nome_do_arquivo]

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para exibir ajuda
show_help() {
    echo -e "${BLUE}=== Compilador MQL5 ===${NC}"
    echo ""
    echo "Uso: $0 [nome_do_arquivo]"
    echo ""
    echo "Opções:"
    echo "  -h, --help     Exibe esta ajuda"
    echo "  -l, --list     Lista todos os arquivos .mq5 disponíveis"
    echo "  -v, --verbose  Modo verboso"
    echo ""
    echo "Exemplos:"
    echo "  $0 ExpertMACD"
    echo "  $0 ExpertMACD.mq5"
    echo "  $0 -l"
    echo ""
}

# Função para listar arquivos MQL5
list_mql5_files() {
    echo -e "${BLUE}=== Arquivos MQL5 disponíveis ===${NC}"
    echo ""
    if ls *.mq5 1> /dev/null 2>&1; then
        for file in *.mq5; do
            if [[ -f "$file" ]]; then
                echo -e "${GREEN}✓${NC} $file"
            fi
        done
    else
        echo -e "${YELLOW}⚠ Nenhum arquivo .mq5 encontrado no diretório atual${NC}"
    fi
    echo ""
}

# Função para verificar se o arquivo existe
check_file_exists() {
    local filename="$1"
    
    # Adiciona extensão .mq5 se não estiver presente
    if [[ ! "$filename" =~ \.mq5$ ]]; then
        filename="${filename}.mq5"
    fi
    
    if [[ -f "$filename" ]]; then
        echo "$filename"
        return 0
    else
        return 1
    fi
}

# Função para compilar com MetaEditor (Windows via Wine)
compile_with_metaeditor() {
    local file="$1"
    local verbose="$2"
    
    echo -e "${YELLOW}Tentando compilar com MetaEditor via Wine...${NC}"
    
    # Procura por instalação do MetaTrader 5
    MT5_PATHS=(
        "$HOME/.wine/drive_c/Program Files/MetaTrader 5"
        "$HOME/.wine/drive_c/Program Files (x86)/MetaTrader 5"
        "/opt/metatrader5"
    )
    
    METAEDITOR_PATH=""
    for path in "${MT5_PATHS[@]}"; do
        if [[ -f "$path/metaeditor64.exe" ]]; then
            METAEDITOR_PATH="$path/metaeditor64.exe"
            break
        elif [[ -f "$path/metaeditor.exe" ]]; then
            METAEDITOR_PATH="$path/metaeditor.exe"
            break
        fi
    done
    
    if [[ -n "$METAEDITOR_PATH" ]]; then
        echo -e "${GREEN}MetaEditor encontrado: $METAEDITOR_PATH${NC}"
        
        # Comando de compilação
        if [[ "$verbose" == "true" ]]; then
            wine "$METAEDITOR_PATH" /compile:"$(pwd)/$file" /log
        else
            wine "$METAEDITOR_PATH" /compile:"$(pwd)/$file" > /dev/null 2>&1
        fi
        
        # Verifica se a compilação foi bem-sucedida
        local ex5_file="${file%.mq5}.ex5"
        if [[ -f "$ex5_file" ]]; then
            echo -e "${GREEN}✓ Compilação bem-sucedida: $ex5_file${NC}"
            return 0
        else
            echo -e "${RED}✗ Falha na compilação${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ MetaEditor não encontrado${NC}"
        return 1
    fi
}

# Função para compilar com compilador alternativo (se disponível)
compile_alternative() {
    local file="$1"
    local verbose="$2"
    
    echo -e "${YELLOW}Procurando por compiladores alternativos...${NC}"
    
    # Verifica se existe um compilador MQL5 personalizado
    if command -v mql5-compiler &> /dev/null; then
        echo -e "${GREEN}Compilador MQL5 personalizado encontrado${NC}"
        if [[ "$verbose" == "true" ]]; then
            mql5-compiler "$file"
        else
            mql5-compiler "$file" > /dev/null 2>&1
        fi
        return $?
    fi
    
    # Verifica se existe um script de compilação personalizado
    if [[ -f "./custom_compiler.sh" ]]; then
        echo -e "${GREEN}Script de compilação personalizado encontrado${NC}"
        if [[ "$verbose" == "true" ]]; then
            ./custom_compiler.sh "$file"
        else
            ./custom_compiler.sh "$file" > /dev/null 2>&1
        fi
        return $?
    fi
    
    echo -e "${RED}✗ Nenhum compilador alternativo encontrado${NC}"
    return 1
}

# Função principal de compilação
compile_mql5() {
    local filename="$1"
    local verbose="$2"
    
    echo -e "${BLUE}=== Compilando $filename ===${NC}"
    echo ""
    
    # Verifica se o arquivo existe
    local full_filename
    if full_filename=$(check_file_exists "$filename"); then
        echo -e "${GREEN}✓ Arquivo encontrado: $full_filename${NC}"
    else
        echo -e "${RED}✗ Arquivo não encontrado: $filename${NC}"
        echo -e "${YELLOW}Arquivos disponíveis:${NC}"
        list_mql5_files
        exit 1
    fi
    
    # Tenta compilar com diferentes métodos
    echo -e "${YELLOW}Iniciando compilação...${NC}"
    echo ""
    
    # Método 1: MetaEditor via Wine
    if command -v wine &> /dev/null; then
        if compile_with_metaeditor "$full_filename" "$verbose"; then
            echo -e "${GREEN}🎉 Compilação concluída com sucesso!${NC}"
            exit 0
        fi
    else
        echo -e "${YELLOW}⚠ Wine não está instalado${NC}"
    fi
    
    # Método 2: Compilador alternativo
    if compile_alternative "$full_filename" "$verbose"; then
        echo -e "${GREEN}🎉 Compilação concluída com sucesso!${NC}"
        exit 0
    fi
    
    # Se chegou até aqui, nenhum método funcionou
    echo ""
    echo -e "${RED}✗ Não foi possível compilar o arquivo${NC}"
    echo -e "${YELLOW}Para compilar arquivos MQL5, você precisa de:${NC}"
    echo "1. MetaTrader 5 instalado via Wine"
    echo "2. Um compilador MQL5 alternativo"
    echo "3. Um script de compilação personalizado (custom_compiler.sh)"
    echo ""
    echo -e "${BLUE}Instruções para instalar o MetaTrader 5 via Wine:${NC}"
    echo "1. sudo apt update && sudo apt install wine"
    echo "2. Baixe e instale o MetaTrader 5"
    echo "3. Execute novamente este script"
    echo ""
    exit 1
}

# Processa argumentos da linha de comando
VERBOSE=false
FILENAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--list)
            list_mql5_files
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -*)
            echo -e "${RED}Opção desconhecida: $1${NC}"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$FILENAME" ]]; then
                FILENAME="$1"
            else
                echo -e "${RED}Muitos argumentos fornecidos${NC}"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Se nenhum arquivo foi especificado, solicita ao usuário
if [[ -z "$FILENAME" ]]; then
    echo -e "${BLUE}=== Compilador MQL5 ===${NC}"
    echo ""
    echo -e "${YELLOW}Arquivos MQL5 disponíveis:${NC}"
    list_mql5_files
    
    echo -n "Digite o nome do arquivo para compilar (sem ou com extensão .mq5): "
    read -r FILENAME
    
    if [[ -z "$FILENAME" ]]; then
        echo -e "${RED}✗ Nenhum arquivo especificado${NC}"
        exit 1
    fi
fi

# Executa a compilação
compile_mql5 "$FILENAME" "$VERBOSE"