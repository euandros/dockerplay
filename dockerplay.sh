#!/bin/bash

set -e

# Tratamento de interrupção
trap cleanup EXIT
trap 'echo -e "\n⚠️ Script interrompido pelo usuário"; exit 1' INT

# Cores para melhor visualização
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funções para feedback visual
show_progress() {
    echo -e "\n${BLUE}⏳ $1${NC}"
}

show_success() {
    echo -e "\n${GREEN}✅ $1${NC}"
}

show_error() {
    echo -e "\n${RED}❌ $1${NC}"
}

show_section() {
    local title=$1
    echo -e "\n\n${YELLOW}=== $title ===${NC}\n"
}

# Função para criar um frame visual para a saída
show_command_output() {
    local output=$1
    local width=80
    
    echo -e "\n📋 Saída do comando:"
    echo "┌$([[ $width -gt 0 ]] && printf '─%.0s' $(seq 1 $width))┐"
    
    while IFS= read -r line; do
        printf "│ %-${width}s │\n" "${line:0:$width}"
    done <<< "$output"
    
    echo "└$([[ $width -gt 0 ]] && printf '─%.0s' $(seq 1 $width))┘"
    echo
}

# Funções para mostrar dicas e explicações
show_tip() {
    echo -e "\n${BLUE}💡 Dica: $1${NC}"
}

show_explanation() {
    echo -e "\n${YELLOW}📚 Explicação: $1${NC}"
}

show_objective() {
    echo -e "\n${GREEN}🎯 Objetivo: $1${NC}"
}

show_command_help() {
    echo -e "\n${YELLOW}📖 Ajuda:${NC}"
    echo -e "$1"
}

# Função de limpeza global
cleanup() {
    show_section "Limpeza do Ambiente"
    
    # Verifica Docker Compose
    if [ -f "docker-compose.yml" ]; then
        show_progress "Limpando recursos do Docker Compose..."
        docker-compose down -v 2>/dev/null || true
        rm -f docker-compose.yml 2>/dev/null || true
        show_success "Recursos do Docker Compose limpos!"
    fi

    # Verifica containers em execução
    if docker ps -q &>/dev/null; then
        show_progress "Parando containers em execução..."
        docker stop $(docker ps -q) 2>/dev/null || true
        show_success "Containers parados!"
    fi

    # Remove containers parados
    if docker ps -aq &>/dev/null; then
        show_progress "Removendo containers parados..."
        docker rm $(docker ps -aq) 2>/dev/null || true
        show_success "Containers removidos!"
    fi

    # Remove volumes não utilizados
    if docker volume ls -q &>/dev/null; then
        show_progress "Removendo volumes não utilizados..."
        docker volume prune -f 2>/dev/null || true
        show_success "Volumes removidos!"
    fi

    # Remove redes não utilizadas
    if docker network ls --filter "type=custom" -q &>/dev/null; then
        show_progress "Removendo redes não utilizadas..."
        docker network prune -f 2>/dev/null || true
        show_success "Redes removidas!"
    fi

    # Remove arquivos temporários
    local temp_files=(app.py requirements.txt Dockerfile)
    for file in "${temp_files[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
        fi
    done

    show_success "Limpeza concluída!"
}

# Função para executar comando com timeout
execute_with_timeout() {
    local cmd=$1
    local timeout=${2:-30}
    local description=${3:-"comando"}
    
    show_progress "Executando $description..."
    timeout $timeout bash -c "$cmd" || {
        show_error "O $description excedeu o tempo limite de $timeout segundos"
        return 1
    }
}

# Verificações iniciais
check_requirements() {
    show_section "Verificação de Requisitos"
    local missing_requirements=false

    show_objective "Verificar se todos os componentes necessários estão instalados e funcionando"

    # Verifica Docker
    if ! command -v docker &> /dev/null; then
        show_error "Docker não está instalado"
        show_tip "Instale o Docker seguindo as instruções em: https://docs.docker.com/get-docker/"
        show_command_help "Para instalar no Ubuntu: sudo apt-get install docker.io"
        missing_requirements=true
    else
        local docker_version=$(docker --version)
        show_success "Docker está instalado ($docker_version)"
    fi

    # Verifica Docker daemon
    if ! docker info &> /dev/null; then
        show_error "O daemon do Docker não está rodando"
        show_tip "Inicie o serviço do Docker:"
        show_command_help "Linux: sudo systemctl start docker
Windows/Mac: Inicie o Docker Desktop"
        missing_requirements=true
    else
        show_success "Docker daemon está rodando"
    fi

    # Verifica permissões do usuário
    if ! docker info &> /dev/null && [ "$EUID" -ne 0 ]; then
        show_error "Usuário atual não tem permissão para executar comandos Docker"
        show_tip "Adicione seu usuário ao grupo docker:"
        show_command_help "sudo usermod -aG docker $USER
Depois, faça logout e login novamente"
        missing_requirements=true
    fi

    if [ "$missing_requirements" = true ]; then
        show_error "Por favor, instale/configure os requisitos faltantes e tente novamente"
        return 1
    fi

    show_success "Todos os requisitos estão satisfeitos!"
    echo -e "\n----------------------------------------\n"
    return 0
}

# Função para validar se o comando foi realmente executado
validate_command_execution() {
    local expected_command=$1
    local actual_command
    
    # Mostra o comando esperado de forma destacada
    echo -e "\n${YELLOW}Comando esperado:${NC} $expected_command"
    
    # Se houver uma descrição do comando, mostra
    if [ -n "$2" ]; then
        show_command_help "$2"
    fi
    
    read -p "🔵 Digite o comando: " actual_command
    
    # Remove espaços extras e normaliza o comando
    actual_command=$(echo "$actual_command" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    expected_command=$(echo "$expected_command" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    if [[ "$actual_command" != "$expected_command" ]]; then
        show_error "Comando incorreto!"
        echo -e "\nEsperado: $expected_command"
        echo "Digitado: $actual_command"
        show_tip "Digite o comando exatamente como mostrado"
        return 1
    fi
    
    return 0
}

# Função para verificar comando e saída com feedback educacional
check_command_and_output() {
    local expected_command=$1
    local expected_output=$2
    local error_message=$3
    local check_type=${4:-output}
    local command_explanation=$5
    local error_explanation=$6
    local success_explanation=$7
    local command_help=$8

    local command_executed=false
    local output
    local return_code

    if [ -n "$command_explanation" ]; then
        show_explanation "$command_explanation"
    fi

    while [ "$command_executed" = false ]; do
        if ! validate_command_execution "$expected_command" "$command_help"; then
            if [ -n "$error_explanation" ]; then
                show_tip "$error_explanation"
            fi
            continue
        fi

        show_progress "Executando comando..."
        output=$(eval "$expected_command" 2>&1)
        return_code=$?

        show_command_output "$output"

        if [ $return_code -ne 0 ]; then
            show_error "$error_message"
            if [ -n "$error_explanation" ]; then
                show_tip "$error_explanation"
            fi
            continue
        fi

        if [ "$check_type" = "output" ]; then
            if [[ ! "$output" =~ $expected_output ]]; then
                show_error "A saída não é a esperada"
                if [ -n "$error_explanation" ]; then
                    show_tip "$error_explanation"
                fi
                continue
            fi
        elif [ "$check_type" = "exists" ] && [ -z "$output" ]; then
            show_error "$error_message"
            if [ -n "$error_explanation" ]; then
                show_tip "$error_explanation"
            fi
            continue
        fi

        command_executed=true
    done

    show_success "Comando executado com sucesso!"
    if [ -n "$success_explanation" ]; then
        show_explanation "$success_explanation"
    fi
    echo -e "\n----------------------------------------\n"
    return 0
}

# --- Nível 1 - Básico ---
nivel_1() {
    show_section "Nível 1 - Comandos Básicos do Docker"
    
    show_objective "Neste nível, você aprenderá os comandos básicos do Docker"
    show_explanation "Vamos começar com comandos simples e fundamentais do Docker"
    
    # Limpeza inicial
    show_progress "Verificando ambiente anterior..."
    if docker ps -a | grep -qE 'hello|meu_ubuntu'; then
        show_progress "Containers anteriores encontrados, removendo..."
        docker stop meu_ubuntu hello 2>/dev/null || true
        docker rm meu_ubuntu hello 2>/dev/null || true
        show_success "Containers anteriores removidos!"
    fi

    # Verificar e remover imagens anteriores
    if docker images | grep -q "hello-world"; then
        show_progress "Imagem hello-world encontrada, removendo..."
        docker rmi hello-world 2>/dev/null || true
        show_success "Imagem anterior removida!"
    fi

    echo -e "\n1. Baixar imagem hello-world"
    show_objective "Baixar uma imagem básica do Docker Hub"
    check_command_and_output \
        "docker pull hello-world" \
        "Downloaded newer image|Image is up to date" \
        "Erro ao baixar a imagem" \
        "output" \
        "O comando 'docker pull' baixa imagens do Docker Hub" \
        "Verifique sua conexão com a internet" \
        "Imagem hello-world baixada com sucesso!"

    echo -e "\n2. Executar hello-world"
    show_objective "Criar e executar seu primeiro container Docker"
    check_command_and_output \
        "docker run --name hello hello-world" \
        "Hello from Docker!" \
        "Erro ao executar a imagem" \
        "output" \
        "O comando 'docker run' cria e inicia um novo container" \
        "Verifique se a imagem foi baixada corretamente" \
        "Primeiro container executado com sucesso!"

    echo -e "\n3. Verificar imagem Ubuntu"
    show_objective "Garantir que temos a imagem Ubuntu disponível"
    if ! docker images | grep -q "ubuntu"; then
        show_progress "Baixando imagem Ubuntu..."
        check_command_and_output \
            "docker pull ubuntu" \
            "Downloaded newer image|Image is up to date" \
            "Erro ao baixar a imagem Ubuntu" \
            "output" \
            "Precisamos da imagem Ubuntu para o próximo exercício" \
            "Verifique sua conexão com a internet" \
            "Imagem Ubuntu baixada com sucesso!"
    fi

    echo -e "\n4. Executar container Ubuntu com logs"
    show_objective "Criar um container mais complexo que gera logs"
    check_command_and_output \
        "docker run -d --name meu_ubuntu ubuntu sh -c 'while true; do echo \"Container em execução\"; sleep 5; done'" \
        "[0-9a-f]" \
        "Erro ao criar o container" \
        "output" \
        "Este comando cria um container Ubuntu que gera logs periodicamente" \
        "Verifique se a imagem ubuntu existe localmente" \
        "Container Ubuntu criado com sucesso!"

    # Aguarda para garantir que logs foram gerados
    sleep 6

    echo -e "\n5. Listar containers em execução"
    show_objective "Aprender a listar containers ativos"
    check_command_and_output \
        "docker ps" \
        "meu_ubuntu" \
        "Container não está rodando" \
        "output" \
        "O comando 'docker ps' lista containers em execução" \
        "Verifique se o container foi iniciado corretamente" \
        "Containers listados com sucesso!"

    echo -e "\n6. Verificar logs do container Ubuntu"
    show_objective "Aprender a verificar logs de containers"
    check_command_and_output \
        "docker logs meu_ubuntu" \
        "Container em execução" \
        "Erro ao verificar logs" \
        "output" \
        "O comando 'docker logs' mostra os logs do container" \
        "Verifique se o nome do container está correto" \
        "Logs verificados com sucesso!"

    echo -e "\n7. Parar o container Ubuntu"
    show_objective "Aprender a parar containers em execução"
    check_command_and_output \
        "docker stop meu_ubuntu" \
        "meu_ubuntu" \
        "Erro ao parar o container" \
        "output" \
        "O comando 'docker stop' para a execução de um container" \
        "Verifique se o nome do container está correto" \
        "Container parado com sucesso!"

    echo -e "\n8. Remover containers"
    show_objective "Aprender a remover containers que não são mais necessários"
    check_command_and_output \
        "docker rm meu_ubuntu hello" \
        "meu_ubuntu|hello" \
        "Erro ao remover os containers" \
        "output" \
        "O comando 'docker rm' remove containers parados" \
        "Certifique-se que os containers estão parados" \
        "Containers removidos com sucesso!"

    echo -e "\n9. Remover imagem hello-world"
    show_objective "Aprender a gerenciar imagens locais"
    check_command_and_output \
        "docker rmi hello-world" \
        "Untagged: hello-world:latest|Deleted:" \
        "Erro ao remover a imagem" \
        "output" \
        "O comando 'docker rmi' remove imagens locais" \
        "Verifique se não há containers usando esta imagem" \
        "Imagem removida com sucesso!"

    show_success "Nível 1 concluído com sucesso!"
    show_explanation "Você aprendeu os comandos básicos para gerenciar containers e imagens Docker"
    echo -e "\n----------------------------------------\n"
}

# --- Nível 2 - Intermediário ---
nivel_2() {
    show_section "Nível 2 - Volumes, Redes e Variáveis de Ambiente"
    
    show_objective "Neste nível, você aprenderá conceitos mais avançados do Docker"
    show_explanation "Vamos trabalhar com persistência de dados, comunicação entre containers e configuração de ambiente"

    local VOLUME_NAME="meu_volume"
    local CONTAINER_NAME="meu_container"
    local NETWORK_NAME="minha_rede"

    # Limpeza inicial
    show_progress "Preparando ambiente..."
    
    # Limpa volumes anteriores
    if docker volume ls | grep -q "$VOLUME_NAME"; then
        show_progress "Volume anterior encontrado, removendo..."
        docker volume rm "$VOLUME_NAME" 2>/dev/null || true
    fi

    # Limpa redes anteriores
    if docker network ls | grep -q "$NETWORK_NAME"; then
        show_progress "Rede anterior encontrada, removendo..."
        docker network rm "$NETWORK_NAME" 2>/dev/null || true
    fi

    echo -e "\n1. Criar volume Docker"
    show_objective "Aprender a criar volumes para persistência de dados"
    
    check_command_and_output \
        "docker volume create $VOLUME_NAME" \
        "$VOLUME_NAME" \
        "Erro ao criar o volume" \
        "output" \
        "Volumes permitem que dados persistam mesmo após a remoção do container" \
        "Verifique se não há outro volume com o mesmo nome" \
        "Volume criado com sucesso!" \
        "docker volume create : Cria um novo volume
docker volume ls : Lista volumes
docker volume inspect : Mostra detalhes do volume"

    echo -e "\n2. Listar volumes"
    show_objective "Verificar volumes disponíveis"
    
    check_command_and_output \
        "docker volume ls" \
        "$VOLUME_NAME" \
        "Volume não encontrado" \
        "output" \
        "Este comando lista todos os volumes Docker disponíveis" \
        "O volume deve aparecer na listagem" \
        "Volume listado com sucesso!" \
        "docker volume ls : Lista todos os volumes
docker volume ls -q : Lista apenas os nomes dos volumes"

    echo -e "\n3. Criar container com volume"
    show_objective "Aprender a montar volumes em containers"
    
    check_command_and_output \
        "docker run -d --name $CONTAINER_NAME -v $VOLUME_NAME:/data ubuntu sleep infinity" \
        "[0-9a-f]" \
        "Erro ao criar o container com volume" \
        "output" \
        "O parâmetro -v monta o volume no diretório /data do container" \
        "Verifique se o volume foi criado corretamente" \
        "Container criado com volume montado!" \
        "docker run -v : Monta um volume no container
[VOLUME]:[CAMINHO] : Define onde o volume será montado"

    echo -e "\n4. Criar arquivo no volume"
    show_objective "Testar a persistência de dados no volume"
    
    check_command_and_output \
        "docker exec $CONTAINER_NAME sh -c 'echo \"teste\" > /data/arquivo.txt'" \
        "" \
        "Erro ao criar arquivo" \
        "exists" \
        "Vamos criar um arquivo dentro do volume para testar a persistência" \
        "Verifique se o container está rodando" \
        "Arquivo criado com sucesso!" \
        "docker exec : Executa um comando no container
-i : Modo interativo
-t : Aloca um pseudo-TTY"

    echo -e "\n5. Verificar conteúdo do arquivo"
    show_objective "Confirmar que o arquivo foi criado"
    
    check_command_and_output \
        "docker exec $CONTAINER_NAME cat /data/arquivo.txt" \
        "teste" \
        "Arquivo não encontrado" \
        "output" \
        "Vamos ler o conteúdo do arquivo criado" \
        "Verifique se o arquivo foi criado corretamente" \
        "Arquivo lido com sucesso!" \
        "cat : Mostra o conteúdo do arquivo
ls /data : Lista arquivos no diretório"

    echo -e "\n6. Criar rede Docker"
    show_objective "Aprender a criar redes para comunicação entre containers"
    
    check_command_and_output \
        "docker network create $NETWORK_NAME" \
        "[0-9a-f]" \
        "Erro ao criar a rede" \
        "output" \
        "Redes Docker permitem que containers se comuniquem entre si" \
        "Verifique se não há outra rede com o mesmo nome" \
        "Rede criada com sucesso!" \
        "docker network create : Cria uma nova rede
docker network ls : Lista redes
docker network inspect : Mostra detalhes da rede"

    echo -e "\n7. Criar container na rede"
    show_objective "Aprender a conectar containers à rede"
    
    check_command_and_output \
        "docker run -d --name webserver --network $NETWORK_NAME nginx" \
        "[0-9a-f]" \
        "Erro ao criar container na rede" \
        "output" \
        "Vamos criar um container nginx conectado à nossa rede" \
        "Verifique se a rede foi criada corretamente" \
        "Container criado e conectado à rede!" \
        "docker run --network : Conecta container à rede
--network-alias : Define um alias para o container na rede"

    # Limpeza final
    show_progress "Realizando limpeza..."
    docker stop $CONTAINER_NAME webserver 2>/dev/null || true
    docker rm $CONTAINER_NAME webserver 2>/dev/null || true
    docker volume rm $VOLUME_NAME 2>/dev/null || true
    docker network rm $NETWORK_NAME 2>/dev/null || true

    show_success "Nível 2 concluído com sucesso!"
    show_explanation "Você aprendeu sobre volumes para persistência de dados e redes para comunicação entre containers"
    echo -e "\n----------------------------------------\n"
}

# --- Nível 3 - Dockerfile ---
nivel_3() {
    show_section "Nível 3 - Criação de Imagens com Dockerfile"
    
    show_objective "Neste nível, você aprenderá a criar suas próprias imagens Docker"
    show_explanation "O Dockerfile é um arquivo de configuração que contém instruções para construir uma imagem Docker"

    # Limpeza inicial
    show_progress "Preparando ambiente..."
    local files_to_clean=(app.py requirements.txt Dockerfile)
    for file in "${files_to_clean[@]}"; do
        [ -f "$file" ] && rm -f "$file"
    done

    # Remove imagem anterior se existir
    if docker images | grep -q "minha_app"; then
        show_progress "Removendo imagem anterior..."
        docker rmi minha_app 2>/dev/null || true
    fi

    echo -e "\n1. Criar aplicação Python simples"
    show_objective "Preparar uma aplicação simples para containerização"
    
    show_progress "Criando app.py..."
    cat > app.py << 'EOF'
# Aplicação Python simples
print("Olá! Esta é uma aplicação Python em um container Docker!")
EOF

    show_progress "Criando requirements.txt..."
    touch requirements.txt

    show_success "Arquivos da aplicação criados!"
    show_explanation "Criamos uma aplicação Python simples e um arquivo de dependências vazio"

    echo -e "\n2. Criar Dockerfile"
    show_objective "Aprender a escrever um Dockerfile básico"
    show_explanation "O Dockerfile define como sua aplicação será empacotada"

    show_command_help "Um Dockerfile básico deve conter:
FROM : Define a imagem base
WORKDIR : Define o diretório de trabalho
COPY : Copia arquivos para a imagem
RUN : Executa comandos durante a construção
CMD : Define o comando padrão do container"

    show_progress "Criando Dockerfile..."
    cat > Dockerfile << 'EOF'
# Usa Python 3.9 como base
FROM python:3.9-slim

# Define o diretório de trabalho
WORKDIR /app

# Copia os arquivos necessários
COPY app.py .
COPY requirements.txt .

# Instala as dependências
RUN pip install --no-cache-dir -r requirements.txt

# Define o comando padrão
CMD ["python", "app.py"]
EOF

    show_success "Dockerfile criado!"
    
    echo -e "\n3. Verificar estrutura do Dockerfile"
    show_objective "Entender cada instrução do Dockerfile"
    
    check_command_and_output \
        "cat Dockerfile" \
        "FROM python" \
        "Dockerfile não encontrado" \
        "output" \
        "Vamos analisar o conteúdo do Dockerfile" \
        "Verifique se o arquivo foi criado corretamente" \
        "Este é um Dockerfile básico para uma aplicação Python" \
        "FROM : Imagem base
WORKDIR : Diretório de trabalho
COPY : Copia arquivos
RUN : Executa comandos
CMD : Comando padrão"

    echo -e "\n4. Construir imagem"
    show_objective "Aprender a construir uma imagem a partir do Dockerfile"
    
    check_command_and_output \
        "docker build -t minha_app ." \
        "Successfully built" \
        "Erro ao construir a imagem" \
        "output" \
        "O comando 'docker build' cria uma imagem a partir do Dockerfile" \
        "Verifique se todos os arquivos necessários estão presentes" \
        "Imagem construída com sucesso!" \
        "docker build : Constrói uma imagem
-t : Define uma tag/nome
. : Usa o diretório atual"

    echo -e "\n5. Verificar imagem criada"
    show_objective "Aprender a listar e verificar imagens"
    
    check_command_and_output \
        "docker images minha_app" \
        "minha_app" \
        "Imagem não encontrada" \
        "output" \
        "Vamos verificar se a imagem foi criada corretamente" \
        "A imagem deve aparecer na listagem" \
        "Imagem encontrada!" \
        "docker images : Lista imagens
docker image inspect : Mostra detalhes da imagem"

    echo -e "\n6. Executar container com a nova imagem"
    show_objective "Testar a imagem criada"
    
    check_command_and_output \
        "docker run --name minha_app_container minha_app" \
        "Olá!" \
        "Erro ao executar o container" \
        "output" \
        "Vamos executar um container com nossa imagem" \
        "Verifique se a imagem foi construída corretamente" \
        "Aplicação executada com sucesso!" \
        "docker run : Cria e inicia um container
--name : Define um nome para o container"

    # Limpeza final
    show_progress "Realizando limpeza..."
    docker rm minha_app_container 2>/dev/null || true
    docker rmi minha_app 2>/dev/null || true
    rm -f "${files_to_clean[@]}" 2>/dev/null || true

    show_success "Nível 3 concluído com sucesso!"
    show_explanation "Você aprendeu a criar suas próprias imagens Docker usando Dockerfile"
    echo -e "\n----------------------------------------\n"
}

# Função principal
main() {
    clear
    show_section "Tutorial Interativo Docker"
    
    show_explanation "Este tutorial irá guiá-lo através dos conceitos fundamentais do Docker.

O tutorial está dividido em 3 níveis:

1. Básico
   - Comandos essenciais do Docker
   - Gerenciamento de containers
   - Manipulação de imagens

2. Intermediário
   - Volumes para persistência de dados
   - Redes Docker
   - Variáveis de ambiente

3. Avançado
   - Criação de Dockerfile
   - Construção de imagens
   - Boas práticas

Em cada nível você receberá:
✓ Instruções claras do que deve ser feito
✓ Explicações sobre cada conceito
✓ Exemplos práticos
✓ Dicas em caso de erro
✓ Ajuda detalhada dos comandos
✓ Feedback sobre suas ações

Recomendações:
• Leia atentamente as explicações
• Execute os comandos exatamente como mostrado
• Use as dicas quando tiver dúvidas
• Experimente os comandos adicionais sugeridos"

    # Verificação inicial de requisitos
    if ! check_requirements; then
        show_error "Falha na verificação de requisitos. Corrija os problemas e tente novamente."
        exit 1
    fi

    # Nível 1
    read -p "Pressione Enter para começar o Nível 1 (Básico)..."
    if ! nivel_1; then
        show_error "Erro ao completar o Nível 1"
        show_tip "Revise os conceitos básicos e tente novamente"
        exit 1
    fi
    
    show_section "🎉 Nível 1 Concluído!"
    show_explanation "Você já sabe:
✓ Baixar imagens do Docker Hub
✓ Criar e executar containers
✓ Listar containers em execução
✓ Parar e remover containers
✓ Gerenciar imagens locais"
    
    # Nível 2
    read -p "Pressione Enter para continuar para o Nível 2 (Intermediário)..."
    if ! nivel_2; then
        show_error "Erro ao completar o Nível 2"
        show_tip "Revise os conceitos de volumes e redes e tente novamente"
        exit 1
    fi
    
    show_section "🎉 Nível 2 Concluído!"
    show_explanation "Você já sabe:
✓ Criar e gerenciar volumes
✓ Persistir dados entre containers
✓ Criar redes Docker
✓ Conectar containers em rede
✓ Usar variáveis de ambiente"
    
    # Nível 3
    read -p "Pressione Enter para continuar para o Nível 3 (Avançado)..."
    if ! nivel_3; then
        show_error "Erro ao completar o Nível 3"
        show_tip "Revise os conceitos de Dockerfile e tente novamente"
        exit 1
    fi

    # Mensagem final de conclusão
    show_section "🎊 Parabéns! Tutorial Concluído! 🎊"
    
    show_success "Você completou com sucesso todos os níveis do tutorial Docker!"
    
    show_explanation "Conceitos dominados:
✓ Comandos básicos do Docker
✓ Gerenciamento de containers e imagens
✓ Volumes para persistência de dados
✓ Redes Docker para comunicação
✓ Criação de imagens com Dockerfile
✓ Boas práticas de containerização

Próximos passos sugeridos:
1. Explore o Docker Compose para múltiplos containers
2. Aprenda sobre Docker Swarm para orquestração
3. Estude Kubernetes para ambientes mais complexos
4. Pratique criando seus próprios projetos
5. Aprenda sobre segurança em containers

Recursos adicionais:
• Documentação oficial: https://docs.docker.com
• Docker Hub: https://hub.docker.com
• Docker GitHub: https://github.com/docker
• Docker Blog: https://www.docker.com/blog"

    show_tip "Mantenha este script para referência e prática adicional"
    
    echo -e "\n----------------------------------------\n"
}

# Execução do script
main
