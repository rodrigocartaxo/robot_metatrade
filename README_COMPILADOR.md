# Compilador MQL5

Este script permite compilar arquivos MQL5 com um nome específico fornecido pelo usuário.

## Arquivos

- `compile_mql5.sh` - Script principal de compilação
- `custom_compiler.sh` - Script personalizado de compilação (exemplo)

## Uso

### Compilação Básica

```bash
# Compilar um arquivo específico
./compile_mql5.sh ExpertMACD

# Ou com extensão
./compile_mql5.sh ExpertMACD.mq5
```

### Opções Disponíveis

```bash
# Exibir ajuda
./compile_mql5.sh -h
./compile_mql5.sh --help

# Listar arquivos MQL5 disponíveis
./compile_mql5.sh -l
./compile_mql5.sh --list

# Modo verboso (mais detalhes)
./compile_mql5.sh -v ExpertMACD
./compile_mql5.sh --verbose ExpertMACD
```

### Modo Interativo

Se executar o script sem parâmetros, ele entrará em modo interativo:

```bash
./compile_mql5.sh
```

O script mostrará os arquivos disponíveis e pedirá para você digitar o nome do arquivo.

## Métodos de Compilação

O script tenta compilar usando diferentes métodos, na seguinte ordem:

### 1. MetaEditor via Wine (Recomendado)

Se você tiver o MetaTrader 5 instalado via Wine, o script usará o MetaEditor oficial.

**Instalação do Wine e MetaTrader 5:**

```bash
# Instalar Wine
sudo apt update
sudo apt install wine

# Configurar Wine
winecfg

# Baixar e instalar MetaTrader 5
# (Execute o instalador do MT5 com Wine)
```

### 2. Compilador Personalizado

O script procura por:
- Um comando `mql5-compiler` no PATH
- Um arquivo `custom_compiler.sh` no diretório atual

## Script Personalizado

O arquivo `custom_compiler.sh` é um exemplo de compilador personalizado que:

- Valida a sintaxe básica do MQL5
- Verifica includes e propriedades
- Simula a compilação criando/atualizando o arquivo .ex5

Você pode modificar este script para:
- Integrar com outros compiladores
- Adicionar validações específicas
- Executar testes automatizados
- Fazer deploy automático

## Exemplos de Uso

```bash
# Listar arquivos disponíveis
$ ./compile_mql5.sh -l
=== Arquivos MQL5 disponíveis ===

✓ BOT_TIME_RANGE.mq5
✓ ExpertMACD.mq5
✓ ExpertMAMA.mq5
✓ ExpertMAPSAR.mq5
✓ ExpertMAPSARSizeOptimized.mq5

# Compilar um arquivo específico
$ ./compile_mql5.sh ExpertMACD
=== Compilando ExpertMACD ===

✓ Arquivo encontrado: ExpertMACD.mq5
Iniciando compilação...
🎉 Compilação concluída com sucesso!

# Modo interativo
$ ./compile_mql5.sh
=== Compilador MQL5 ===

Arquivos MQL5 disponíveis:
✓ BOT_TIME_RANGE.mq5
✓ ExpertMACD.mq5
...

Digite o nome do arquivo para compilar: ExpertMACD
```

## Personalização

### Modificar Caminhos do MetaTrader

No arquivo `compile_mql5.sh`, você pode modificar a array `MT5_PATHS` para incluir caminhos personalizados:

```bash
MT5_PATHS=(
    "$HOME/.wine/drive_c/Program Files/MetaTrader 5"
    "$HOME/.wine/drive_c/Program Files (x86)/MetaTrader 5"
    "/opt/metatrader5"
    "/caminho/personalizado/para/mt5"  # Adicione aqui
)
```

### Criar Compilador Personalizado

Crie um arquivo `custom_compiler.sh` com sua lógica específica:

```bash
#!/bin/bash
FILE="$1"

# Sua lógica de compilação aqui
echo "Compilando $FILE..."

# Exemplo: usar um compilador específico
my_mql5_compiler "$FILE"

# Verificar se foi bem-sucedido
if [[ $? -eq 0 ]]; then
    echo "✓ Compilação bem-sucedida"
    exit 0
else
    echo "✗ Falha na compilação"
    exit 1
fi
```

## Solução de Problemas

### Wine não encontrado
```bash
sudo apt update
sudo apt install wine
```

### MetaEditor não encontrado
Verifique se o MetaTrader 5 está instalado corretamente via Wine.

### Arquivo não encontrado
Use `./compile_mql5.sh -l` para ver os arquivos disponíveis.

### Permissões
```bash
chmod +x compile_mql5.sh
chmod +x custom_compiler.sh
```

## Contribuição

Para adicionar novos métodos de compilação, modifique as funções:
- `compile_with_metaeditor()` - Para MetaEditor via Wine
- `compile_alternative()` - Para compiladores alternativos

## Licença

Este script é fornecido como está, para uso livre e modificação conforme necessário.