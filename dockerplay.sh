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

# Função para instalar o Docker e requisitos
install_docker() {
    show_section "Instalação do Docker"
    
    # Detecta o sistema operacional
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
    else
        show_error "Sistema operacional não suportado"
        return 1
    fi

    show_progress "Detectado sistema: $OS $VERSION"

    case "$OS" in
        "Ubuntu"|"Debian GNU/Linux")
            show_progress "Instalando Docker no Ubuntu/Debian..."
            
            # Remove versões antigas
            sudo apt-get remove docker docker-engine docker.io containerd runc 2>/dev/null || true
            
            # Atualiza os repositórios
            show_progress "Atualizando repositórios..."
            sudo apt-get update
            
            # Instala dependências
            show_progress "Instalando dependências..."
            sudo apt-get install -y \
                apt-transport-https \
                ca-certificates \
                curl \
                gnupg \
                lsb-release

            # Adiciona a chave GPG oficial do Docker
            show_progress "Adicionando chave GPG do Docker..."
            curl -fsSL https://download.docker.com/linux/$ID/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

            # Adiciona o repositório do Docker
            show_progress "Configurando repositório do Docker..."
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$ID \
                $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

            # Atualiza novamente e instala o Docker
            show_progress "Instalando Docker..."
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

            # Adiciona usuário ao grupo docker
            show_progress "Configurando permissões..."
            sudo usermod -aG docker $USER
            ;;
            
        "CentOS Linux"|"Red Hat Enterprise Linux"|"Fedora")
            show_progress "Instalando Docker no CentOS/RHEL/Fedora..."
            
            # Remove versões antigas
            sudo yum remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
            
            # Instala dependências
            show_progress "Instalando dependências..."
            sudo yum install -y yum-utils

            # Adiciona repositório do Docker
            show_progress "Configurando repositório do Docker..."
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

            # Instala o Docker
            show_progress "Instalando Docker..."
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

            # Adiciona usuário ao grupo docker
            show_progress "Configurando permissões..."
            sudo usermod -aG docker $USER
            ;;
            
        *)
            show_error "Sistema operacional não suportado: $OS"
            show_tip "Por favor, visite https://docs.docker.com/engine/install/ para instruções específicas"
            return 1
            ;;
    esac

    # Inicia o serviço Docker
    show_progress "Iniciando serviço Docker..."
    sudo systemctl start docker
    sudo systemctl enable docker

    show_success "Docker instalado com sucesso!"
    show_tip "Para que as alterações de grupo tenham efeito, você precisa fazer logout e login novamente"
    show_tip "Após fazer logout e login, execute este script novamente"

    # Verifica se precisa fazer logout
    if ! groups | grep -q docker; then
        show_explanation "É necessário fazer logout e login para que as alterações de grupo tenham efeito"
        read -p "Pressione Enter para fazer logout agora..."
        kill -TERM -1
    fi

    return 0
}

# Verificações iniciais
check_requirements() {
    show_section "Verificação de Requisitos"
    local missing_requirements=false

    show_objective "Verificar se todos os componentes necessários estão instalados e funcionando"

    # Verifica Docker
    if ! command -v docker &> /dev/null; then
        show_error "Docker não está instalado"
        show_tip "Vamos tentar instalar o Docker automaticamente"
        if ! install_docker; then
            show_error "Falha na instalação automática do Docker"
            return 1
        fi
    else
        local docker_version=$(docker --version)
        show_success "Docker está instalado ($docker_version)"
    fi

    # Verifica Docker daemon
    if ! docker info &> /dev/null; then
        show_error "O daemon do Docker não está rodando"
        show_tip "Tentando iniciar o serviço do Docker..."
        sudo systemctl start docker || {
            show_error "Não foi possível iniciar o Docker"
            show_tip "Execute: sudo systemctl start docker"
            missing_requirements=true
        }
    else
        show_success "Docker daemon está rodando"
    fi

    # Verifica permissões do usuário
    if ! docker info &> /dev/null && [ "$EUID" -ne 0 ]; then
        show_error "Usuário atual não tem permissão para executar comandos Docker"
        show_tip "Tentando adicionar usuário ao grupo docker..."
        sudo usermod -aG docker $USER
        show_tip "Por favor, faça logout e login novamente para que as alterações tenham efeito"
        return 1
    fi

    if [ "$missing_requirements" = true ]; then
        show_error "Por favor, corrija os problemas e tente novamente"
        return 1
    fi

    show_success "Todos os requisitos estão satisfeitos!"
    echo -e "\n----------------------------------------\n"
    return 0
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
    
    # Limpa containers anteriores
    if docker ps -a | grep -qE "$CONTAINER_NAME|webserver"; then
        show_progress "Containers anteriores encontrados, removendo..."
        docker stop $CONTAINER_NAME webserver 2>/dev/null || true
        docker rm $CONTAINER_NAME webserver 2>/dev/null || true
        show_success "Containers anteriores removidos!"
    fi
    
    # Limpa volumes anteriores
    if docker volume ls | grep -q "$VOLUME_NAME"; then
        show_progress "Volume anterior encontrado, removendo..."
        docker volume rm "$VOLUME_NAME" 2>/dev/null || true
        show_success "Volume anterior removido!"
    fi

    # Limpa redes anteriores
    if docker network ls | grep -q "$NETWORK_NAME"; then
        show_progress "Rede anterior encontrada, removendo..."
        docker network rm "$NETWORK_NAME" 2>/dev/null || true
        show_success "Rede anterior removida!"
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
docker volume inspect : Mostra detalhes do volume"

    echo -e "\n3. Criar container com volume"
    show_objective "Aprender a montar volumes em containers"
    check_command_and_output \
        "docker run -d --name $CONTAINER_NAME -v $VOLUME_NAME:/data ubuntu tail -f /dev/null" \
        "[0-9a-f]" \
        "Erro ao criar container" \
        "output" \
        "Este comando cria um container que usa nosso volume" \
        "Verifique se o volume existe" \
        "Container criado com volume!" \
        "docker run -v : Monta um volume no container
-d : Executa em background
tail -f /dev/null : Mantém o container rodando"

    echo -e "\n4. Criar arquivo no volume"
    show_objective "Testar a persistência de dados no volume"
    check_command_and_output \
        "docker exec $CONTAINER_NAME sh -c 'echo \"teste\" > /data/arquivo.txt && echo \"Arquivo criado\"'" \
        "Arquivo criado" \
        "Erro ao criar arquivo" \
        "output" \
        "Vamos criar um arquivo dentro do volume" \
        "Verifique se o container está rodando" \
        "Arquivo criado com sucesso!" \
        "docker exec : Executa comando no container
echo : Cria arquivo com conteúdo"

    echo -e "\n5. Verificar conteúdo do arquivo"
    show_objective "Confirmar que o arquivo foi criado corretamente"
    check_command_and_output \
        "docker exec $CONTAINER_NAME cat /data/arquivo.txt" \
        "teste" \
        "Arquivo não encontrado ou vazio" \
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
        "Erro ao criar rede" \
        "output" \
        "Redes permitem que containers se comuniquem entre si" \
        "Verifique se não há outra rede com o mesmo nome" \
        "Rede criada com sucesso!" \
        "docker network create : Cria uma nova rede
docker network ls : Lista redes
docker network inspect : Mostra detalhes da rede"

    echo -e "\n7. Criar container na rede"
    show_objective "Aprender a conectar containers em redes"
    check_command_and_output \
        "docker run -d --name webserver --network $NETWORK_NAME nginx" \
        "[0-9a-f]" \
        "Erro ao criar container" \
        "output" \
        "Vamos criar um container nginx conectado à nossa rede" \
        "Verifique se a rede foi criada corretamente" \
        "Container criado e conectado à rede!" \
        "docker run --network : Conecta container à rede
--network-alias : Define um alias para o container na rede"

    echo -e "\n8. Verificar containers na rede"
    show_objective "Aprender a inspecionar redes Docker"
    check_command_and_output \
        "docker network inspect $NETWORK_NAME" \
        "webserver" \
        "Erro ao inspecionar rede" \
        "output" \
        "Vamos verificar quais containers estão conectados à rede" \
        "Verifique se o container foi criado corretamente" \
        "Rede inspecionada com sucesso!" \
        "docker network inspect : Mostra detalhes da rede
docker network connect : Conecta container à rede
docker network disconnect : Desconecta container da rede"

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

# --- Nível 3 - Avançado ---
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

    # Remove imagem e container anteriores se existirem
    if docker ps -a | grep -q "minha_app_container"; then
        show_progress "Removendo container anterior..."
        docker stop minha_app_container 2>/dev/null || true
        docker rm minha_app_container 2>/dev/null || true
    fi

    if docker images | grep -q "minha_app"; then
        show_progress "Removendo imagem anterior..."
        docker rmi minha_app 2>/dev/null || true
    fi

    echo -e "\n1. Criar aplicação Python simples"
    show_objective "Preparar uma aplicação simples para containerização"
    
    show_explanation "Vamos criar um arquivo Python simples que imprime uma mensagem"
    read -p "Pressione Enter para criar o arquivo app.py..."
    
    cat > app.py << 'EOF'
# Aplicação Python simples
print("Olá! Esta é uma aplicação Python em um container Docker!")
EOF

    show_explanation "Agora vamos criar um arquivo de dependências vazio"
    read -p "Pressione Enter para criar o arquivo requirements.txt..."
    touch requirements.txt

    if [ ! -f "app.py" ] || [ ! -f "requirements.txt" ]; then
        show_error "Falha ao criar arquivos da aplicação"
        return 1
    fi

    show_success "Arquivos da aplicação criados!"

    echo -e "\n2. Criar Dockerfile"
    show_objective "Aprender a escrever um Dockerfile básico"
    
    show_explanation "O Dockerfile contém as instruções para construir nossa imagem"
    read -p "Pressione Enter para criar o Dockerfile..."
    
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

    if [ ! -f "Dockerfile" ]; then
        show_error "Falha ao criar Dockerfile"
        return 1
    fi

    show_success "Dockerfile criado!"
    
    echo -e "\nConteúdo do Dockerfile criado:"
    cat Dockerfile
    echo -e "\n"

    echo -e "\n3. Verificar arquivos"
    show_objective "Confirmar que todos os arquivos necessários estão presentes"
    
    show_explanation "Vamos verificar se todos os arquivos necessários foram criados"
    read -p "Pressione Enter para listar os arquivos..."
    
    ls -l app.py requirements.txt Dockerfile

    local missing_files=false
    for file in app.py requirements.txt Dockerfile; do
        if [ ! -f "$file" ]; then
            show_error "Arquivo $file não encontrado"
            missing_files=true
        fi
    done

    if [ "$missing_files" = true ]; then
        show_error "Alguns arquivos necessários estão faltando"
        return 1
    fi

    show_success "Todos os arquivos necessários estão presentes!"

    echo -e "\n4. Construir imagem"
    show_objective "Aprender a construir uma imagem a partir do Dockerfile"
    
    check_command_and_output \
        "docker build -t minha_app ." \
        "naming to docker.io/library/minha_app:latest|#12 DONE" \
        "Erro ao construir a imagem" \
        "output" \
        "O comando 'docker build' cria uma imagem a partir do Dockerfile" \
        "Verifique se todos os arquivos necessários estão presentes" \
        "Imagem construída com sucesso!" \
        "docker build : Constrói uma imagem
-t : Define uma tag/nome
. : Usa o diretório atual"

    # Verificação adicional da imagem
    if ! docker images | grep -q "minha_app"; then
        show_error "A imagem não foi criada corretamente"
        return 1
    fi

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
    docker stop minha_app_container 2>/dev/null || true
    docker rm minha_app_container 2>/dev/null || true
    docker rmi minha_app 2>/dev/null || true
    
    for file in "${files_to_clean[@]}"; do
        rm -f "$file" 2>/dev/null || true
    done

    show_success "Nível 3 concluído com sucesso!"
    show_explanation "Você aprendeu a criar suas próprias imagens Docker usando Dockerfile"
    echo -e "\n----------------------------------------\n"
}

# Função principal
main() {
    clear
    echo -e "\n🐳 Bem-vindo ao Tutorial Interativo de Docker! 🐳\n"
    
    # Verifica requisitos antes de começar
    if ! check_requirements; then
        show_error "Requisitos não satisfeitos. Por favor, corrija os problemas e tente novamente."
        exit 1
    fi

    # Menu principal
    while true; do
        echo -e "\nEscolha um nível para começar:"
        echo "1. Básico - Comandos fundamentais"
        echo "2. Intermediário - Volumes, redes e variáveis de ambiente"
        echo "3. Avançado - Criação de imagens com Dockerfile"
        echo "0. Sair"
        
        read -p "Digite sua escolha (0-3): " choice
        
        case $choice in
            1)
                nivel_1
                ;;
            2)
                nivel_2
                ;;
            3)
                nivel_3
                ;;
            0)
                echo -e "\n👋 Obrigado por usar o Tutorial Interativo de Docker!\n"
                exit 0
                ;;
            *)
                show_error "Opção inválida"
                ;;
        esac
    done
}

# Executa a função principal
main
