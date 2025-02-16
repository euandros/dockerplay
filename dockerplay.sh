#!/bin/bash

set -e

# Função para validar se o comando foi realmente executado
validate_command_execution() {
    local expected_command=$1
    local actual_command
    
    # Obtém o último comando executado do histórico
    actual_command=$(history 1 | awk '{$1=""; print substr($0,2)}' | xargs)
    
    if [[ "$actual_command" != "$expected_command" ]]; then
        echo "❌ Comando incorreto executado!"
        echo "Esperado: $expected_command"
        echo "Executado: $actual_command"
        return 1
    fi
    return 0
}

# Função para verificar comando e saída
check_command_and_output() {
    local expected_command=$1
    local expected_output=$2
    local error_message=$3
    local check_type=${4:-output}

    # Aguarda o usuário executar o comando
    local command_executed=false
    while [ "$command_executed" = false ]; do
        echo "Execute o comando: $expected_command"
        read -p "Pressione Enter após executar o comando..."
        if ! validate_command_execution "$expected_command"; then
            echo "Por favor, execute exatamente o comando solicitado."
            continue
        fi
        command_executed=true
    done

    # Verifica a saída do comando
    output=$(eval "$expected_command" 2>&1)
    return_code=$?

    if [ $return_code -ne 0 ]; then
        echo "❌ $error_message"
        echo "Saída do comando:"
        echo "$output"
        exit 1
    fi

    if [[ "$check_type" == "output" ]]; then
        if [[ ! "$output" =~ $expected_output ]]; then
            echo "❌ O comando foi executado, mas a saída não é a esperada."
            echo "Saída do comando:"
            echo "$output"
            echo "Saída esperada (contendo): $expected_output"
            exit 1
        fi
    elif [[ "$check_type" == "exists" ]]; then
        if [[ -z "$output" ]]; then
            echo "❌ $error_message"
            echo "Saída do comando:"
            echo "$output"
            exit 1
        fi
    fi
    echo "✅ Comando executado com sucesso e saída/existência validada!"
}

# --- Nível 1 - Básico ---
nivel_1() {
    clear
    echo -e "\n### Nível 1 - Básico ###"
    
    echo "1. Baixe a imagem 'hello-world' do Docker Hub."
    check_command_and_output "docker pull hello-world" \
        "Status: Downloaded newer image for hello-world:latest" \
        "Erro ao baixar a imagem. Verifique sua conexão e o nome."
    
    echo "2. Execute a imagem 'hello-world'."
    check_command_and_output "docker run hello-world" \
        "Hello from Docker!" \
        "Erro ao executar a imagem."
    
    echo "3. Liste os contêineres em execução."
    check_command_and_output "docker ps" \
        "CONTAINER ID" \
        "Erro ao listar contêineres."
    
    echo "4. Execute um contêiner Ubuntu interativo e em background."
    check_command_and_output "docker run -it -d --name meu_ubuntu ubuntu bash" \
        "" \
        "Erro ao criar o contêiner."
    
    echo "5. Verifique se o contêiner está rodando."
    check_command_and_output "docker ps" \
        "meu_ubuntu" \
        "Contêiner não está rodando."
    
    echo "6. Pare o contêiner."
    check_command_and_output "docker stop meu_ubuntu" \
        "meu_ubuntu" \
        "Erro ao parar o contêiner."
    
    echo "7. Remova o contêiner."
    check_command_and_output "docker rm meu_ubuntu" \
        "meu_ubuntu" \
        "Erro ao remover o contêiner."
    
    echo "8. Remova a imagem 'hello-world'."
    check_command_and_output "docker rmi hello-world" \
        "Untagged: hello-world:latest" \
        "Erro ao remover a imagem."
    
    echo "🎉 Nível 1 concluído!"
}

# --- Nível 2 - Intermediário ---
nivel_2() {
    clear
    echo -e "\n### Nível 2 - Intermediário ###"

    local VOLUME_NAME="meu_volume"
    local CONTAINER_NAME="meu_container"

    echo "1. Crie um volume chamado '$VOLUME_NAME'."
    check_command_and_output "docker volume create $VOLUME_NAME" \
        "$VOLUME_NAME" \
        "Erro ao criar o volume."

    echo "2. Liste os volumes para verificar a criação."
    check_command_and_output "docker volume ls" \
        "$VOLUME_NAME" \
        "Volume não encontrado." \
        "exists"

    echo "3. Execute um contêiner com o volume."
    check_command_and_output "docker run -d -v $VOLUME_NAME:/data --name $CONTAINER_NAME ubuntu tail -f /dev/null" \
        "" \
        "Erro ao criar o contêiner com volume."

    echo "4. Verifique se o contêiner está rodando."
    check_command_and_output "docker ps" \
        "$CONTAINER_NAME" \
        "Contêiner não está rodando." \
        "exists"

    echo "5. Crie um arquivo no volume."
    check_command_and_output "docker exec $CONTAINER_NAME touch /data/meu_arquivo.txt" \
        "" \
        "Erro ao criar arquivo no volume."

    echo "6. Verifique se o arquivo foi criado."
    check_command_and_output "docker exec $CONTAINER_NAME ls /data" \
        "meu_arquivo.txt" \
        "Arquivo não encontrado." \
        "exists"

    echo "7. Pare e remova o contêiner."
    check_command_and_output "docker stop $CONTAINER_NAME" \
        "$CONTAINER_NAME" \
        "Erro ao parar o contêiner."
    check_command_and_output "docker rm $CONTAINER_NAME" \
        "$CONTAINER_NAME" \
        "Erro ao remover o contêiner."

    echo "8. Crie um novo contêiner para verificar a persistência do volume."
    check_command_and_output "docker run --rm -v $VOLUME_NAME:/data ubuntu ls /data" \
        "meu_arquivo.txt" \
        "Arquivo não persistiu no volume."

    echo "9. Crie uma rede personalizada."
    check_command_and_output "docker network create minha_rede" \
        "minha_rede" \
        "Erro ao criar a rede."

    echo "10. Execute um contêiner nginx na rede criada."
    check_command_and_output "docker run -d --name nginx_rede --network minha_rede nginx" \
        "" \
        "Erro ao criar contêiner na rede."

    echo "11. Verifique a conexão do contêiner à rede."
    check_command_and_output "docker network inspect minha_rede" \
        "nginx_rede" \
        "Contêiner não está conectado à rede." \
        "exists"

    echo "12. Teste variáveis de ambiente."
    check_command_and_output "docker run -d -e MINHA_VAR=teste --name container_env ubuntu tail -f /dev/null" \
        "" \
        "Erro ao criar contêiner com variável de ambiente."
    check_command_and_output "docker exec container_env printenv MINHA_VAR" \
        "teste" \
        "Variável de ambiente não encontrada."

    echo "🎉 Nível 2 concluído!"

    # Limpeza
    echo "Realizando limpeza..."
    docker stop nginx_rede container_env 2>/dev/null || true
    docker rm nginx_rede container_env 2>/dev/null || true
    docker volume rm $VOLUME_NAME 2>/dev/null || true
    docker network rm minha_rede 2>/dev/null || true
}

# --- Nível 3 - Dockerfile ---
nivel_3() {
    clear
    echo -e "\n### Nível 3 - Avançado (Dockerfile) ###"

    echo "1. Criando arquivos necessários..."
    
    # Criar arquivo Python de exemplo
    echo "Criando app.py..."
    cat <<EOF > app.py
# app.py (exemplo simples)
print("Olá do meu app Python!")
EOF

    # Criar requirements.txt
    echo "Criando requirements.txt..."
    cat <<EOF > requirements.txt
# requirements.txt (vazio para este exemplo)
EOF

    echo "2. Crie um Dockerfile com as seguintes instruções:"
    echo "- Use python:3.9 como imagem base"
    echo "- Defina /app como diretório de trabalho"
    echo "- Copie app.py e requirements.txt"
    echo "- Instale as dependências"
    echo "- Configure o comando para executar app.py"
    
    # Aguarda o usuário criar o Dockerfile
    while true; do
        echo "Verifique se o Dockerfile foi criado corretamente..."
        read -p "Pressione Enter após criar o Dockerfile..."
        
        if [ ! -f "Dockerfile" ]; then
            echo "❌ Dockerfile não encontrado!"
            continue
        fi  # Corrigido: removida a chave extra e adicionado 'fi'

        # Verifica cada instrução necessária
        local dockerfile_valid=true
        
        if ! grep -q "^FROM python:3\.9$" Dockerfile; then
            echo "❌ Erro: FROM python:3.9 não encontrado ou incorreto"
            dockerfile_valid=false
        fi
        
        if ! grep -q "^WORKDIR /app$" Dockerfile; then
            echo "❌ Erro: WORKDIR /app não encontrado ou incorreto"
            dockerfile_valid=false
        fi
        
        if ! grep -q "^COPY app\.py \.$" Dockerfile; then
            echo "❌ Erro: COPY app.py . não encontrado ou incorreto"
            dockerfile_valid=false
        fi
        
        if ! grep -q "^COPY requirements\.txt \.$" Dockerfile; then
            echo "❌ Erro: COPY requirements.txt . não encontrado ou incorreto"
            dockerfile_valid=false
        fi
        
        if ! grep -q "^RUN pip install --no-cache-dir -r requirements\.txt$" Dockerfile; then
            echo "❌ Erro: RUN pip install não encontrado ou incorreto"
            dockerfile_valid=false
        fi
        
        if ! grep -q '^CMD \["python", "app\.py"\]$' Dockerfile; then
            echo "❌ Erro: CMD ["python", "app.py"] não encontrado ou incorreto"
            dockerfile_valid=false
        fi

        if [ "$dockerfile_valid" = true ]; then
            echo "✅ Dockerfile validado com sucesso!"
            break
        fi
        
        echo "Por favor, corrija os erros e tente novamente."
    done

    echo "3. Construa a imagem 'meu_app'."
    check_command_and_output "docker build -t meu_app ." \
        "Successfully built" \
        "Erro ao construir a imagem."

    echo "4. Verifique se a imagem foi criada."
    check_command_and_output "docker images" \
        "meu_app" \
        "Imagem não encontrada." \
        "exists"

    echo "5. Execute a imagem em um novo contêiner."
    check_command_and_output "docker run --name meu_app_container meu_app" \
        "Olá do meu app Python!" \
        "Erro ao executar o contêiner."

    echo "6. Verifique os logs do contêiner."
    check_command_and_output "docker logs meu_app_container" \
        "Olá do meu app Python!" \
        "Logs incorretos."

    echo "7. Inspecione o contêiner."
    check_command_and_output "docker inspect meu_app_container" \
        "\"Running\":false" \
        "Contêiner ainda em execução."

    echo "8. Remova o contêiner."
    check_command_and_output "docker rm meu_app_container" \
        "meu_app_container" \
        "Erro ao remover o contêiner."

    echo "9. Remova a imagem."
    check_command_and_output "docker rmi meu_app" \
        "Untagged: meu_app:latest" \
        "Erro ao remover a imagem."

    echo "🎉 Nível 3 concluído!"

    # Limpeza
    echo "Realizando limpeza..."
    rm -f app.py requirements.txt Dockerfile 2>/dev/null || true
}

# --- Nível 4 - Docker Compose ---
nivel_4() {
    clear
    echo -e "\n### Nível 4 - Docker Compose ###"

    echo "1. Criando arquivo docker-compose.yml..."
    cat <<EOF > docker-compose.yml
version: '3.9'
services:
  web:
    image: nginx:latest
    ports:
      - "8081:80"
    depends_on:
      - db
  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: mysecretpassword
    volumes:
      - db_data:/var/lib/postgresql/data
volumes:
  db_data:
EOF

    echo "2. Verifique se o Docker Compose está instalado."
    check_command_and_output "docker-compose version" \
        "docker-compose version" \
        "Docker Compose não está instalado."

    echo "3. Valide o arquivo docker-compose.yml."
    check_command_and_output "docker-compose config" \
        "services" \
        "Erro de sintaxe no arquivo docker-compose.yml."

    echo "4. Liste os serviços definidos."
    check_command_and_output "docker-compose ps" \
        "" \
        "Erro ao listar serviços."

    echo "5. Inicie os serviços em background."
    check_command_and_output "docker-compose up -d" \
        "Creating" \
        "Erro ao iniciar os serviços."

    echo "6. Verifique se os serviços estão rodando."
    check_command_and_output "docker-compose ps" \
        "Up" \
        "Serviços não estão rodando." \
        "exists"

    echo "7. Verifique os logs dos serviços."
    check_command_and_output "docker-compose logs --tail=10" \
        "" \
        "Erro ao verificar logs."

    echo "8. Verifique o status do banco de dados."
    check_command_and_output "docker-compose exec db pg_isready" \
        "accepting connections" \
        "Banco de dados não está pronto."

    echo "9. Teste o acesso ao Nginx."
    check_command_and_output "curl -I localhost:8081" \
        "HTTP/1.1 200 OK" \
        "Nginx não está respondendo."

    echo "10. Pare os serviços."
    check_command_and_output "docker-compose down" \
        "Removing" \
        "Erro ao parar os serviços."

    echo "11. Verifique se os serviços foram parados."
    check_command_and_output "docker-compose ps" \
        "" \
        "Ainda existem serviços rodando."

    echo "🎉 Nível 4 concluído!"

    # Limpeza
    echo "Realizando limpeza..."
    docker-compose down -v 2>/dev/null || true
    rm -f docker-compose.yml 2>/dev/null || true
}

# --- Nível 5 - Docker Swarm ---
nivel_5() {
    clear
    echo -e "\n### Nível 5 - Docker Swarm ###"

    echo "1. Verifique o status atual do Swarm."
    check_command_and_output "docker info | grep Swarm" \
        "Swarm: inactive" \
        "Swarm já está ativo. Por favor, desative-o primeiro."

    echo "2. Inicialize o Swarm."
    check_command_and_output "docker swarm init" \
        "Swarm initialized" \
        "Erro ao inicializar o Swarm."

    echo "3. Verifique os nós do Swarm."
    check_command_and_output "docker node ls" \
        "Leader" \
        "Nó líder não encontrado."

    echo "4. Crie um serviço com 3 réplicas."
    check_command_and_output "docker service create --name meu_servico --replicas 3 nginx" \
        "created" \
        "Erro ao criar o serviço."

    echo "5. Verifique o status do serviço."
    check_command_and_output "docker service ls" \
        "meu_servico" \
        "Serviço não encontrado."

    echo "6. Aguarde as réplicas iniciarem..."
    sleep 10
    check_command_and_output "docker service ps meu_servico" \
        "Running" \
        "Réplicas não estão rodando."

    echo "7. Escale o serviço para 5 réplicas."
    check_command_and_output "docker service scale meu_servico=5" \
        "scaled to 5" \
        "Erro ao escalar o serviço."

    echo "8. Aguarde o escalonamento..."
    sleep 10
    check_command_and_output "docker service ps meu_servico" \
        "Running" \
        "Nem todas as réplicas estão rodando."

    echo "9. Remova o serviço."
    check_command_and_output "docker service rm meu_servico" \
        "meu_servico" \
        "Erro ao remover o serviço."

    echo "10. Deixe o modo Swarm."
    check_command_and_output "docker swarm leave --force" \
        "Node left the swarm" \
        "Erro ao sair do Swarm."

    echo "🎉 Nível 5 concluído!"
}

# Verificações iniciais
if ! command -v docker &> /dev/null; then
    echo "❌ Docker não está instalado. Por favor, instale o Docker."
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ O daemon do Docker não está rodando. Por favor, inicie o Docker."
    exit 1
fi

# Execução principal
echo "🚀 Iniciando tutorial interativo do Docker..."
nivel_1
nivel_2
nivel_3
nivel_4
nivel_5

# Mensagem final
echo -e "\n🎊 Parabéns! Você completou todos os níveis do tutorial Docker! 🎊"
echo "Você aprendeu sobre:"
echo "✅ Comandos básicos do Docker"
echo "✅ Volumes e redes"
echo "✅ Criação de imagens com Dockerfile"
echo "✅ Orquestração com Docker Compose"
echo "✅ Clustering com Docker Swarm"
