#!/bin/sh

BASEDIR="$( cd "$( dirname "${0}" )" && pwd )"
TMP_DIR="/tmp"
NORONHA_INST_FOLDER="/usr/share/noronha-dataops"
NORONHA_BRANCH="develop"
NHA_VENV="/usr/share/noronha-venv"
PIP_HOME="${NHA_VENV}/bin"
OS_NAME=""
OS_VERSION=""

# ANACONDA INSTALLATION DIRS - DISABLED
ANACONDA_HOME="/usr/share/anaconda"
ANACONDA_GROUP="anacondagrp"

# MINICONDA INSTALLATION DIRS
MINICONDA_HOME="/usr/share/miniconda"
MINICONDA_GROUP="minicondagrp"

# CONDA DEFINTION
CONDA_HOME="${MINICONDA_HOME}"
CONDA_GROUP="${MINICONDA_GROUP}"



function get_os_version() {
    echo "Start getting OS version"
    if [ -f /etc/os-release ]; then
        # freedesktop.org and systemd
        . /etc/os-release
        OS_NAME=$NAME
        OS_VERSION=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        # linuxbase.org
        OS_NAME=$(lsb_release -si)
        OS_VERSION=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        # For some versions of Debian/Ubuntu without lsb_release command
        . /etc/lsb-release
        OS_NAME=$DISTRIB_ID
        OS_VERSION=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        # Older Debian/Ubuntu/etc.
        OS_NAME=Debian
        OS_VERSION=$(cat /etc/debian_version)
    elif [ -f /etc/SuSe-release ]; then
        # Older SuSE/etc.
        continue
    elif [ -f /etc/centos-release ]; then
        # CentOS
        OS_NAME=$(cat /etc/centos-release | cut -d' ' -f1)
        OS_VERSION=$(cat /etc/centos-release | cut -d' ' -f2,3,4,5,6)
    elif [ -f /etc/redhat-release ]; then
        # Older Red Hat, CentOS, etc.
        OS_NAME=$(cat /etc/centos-release | cut -d' ' -f1)
        OS_VERSION=$(cat /etc/centos-release | cut -d' ' -f2,3,4,5,6)
    else
        # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
        OS_NAME=$(uname -s)
        OS_VERSION=$(uname -r)
    fi
    echo "OS found: ${OS_NAME}"
    echo "OS version: ${OS_VERSION}"
}

# Get user ID
function set_exec_user()
{
    echo "Start getting exec user"
    if [ "${SUDO_USER}" = "" ]; then
        EXEC_USER="${USER}"
    else
        EXEC_USER="${SUDO_USER}"
    fi
    echo "Configuring Noronha for user ${EXEC_USER}" 
}

# Install Anaconda
function install_anaconda()
{
    echo "Start installing Anaconda"
    ANACONDA_FILE="${TMP_DIR}/Anaconda3-2020.02-Linux-x86_64.sh"
    if [ -f "${ANACONDA_FILE}" ]; then
        echo "${ANACONDA_FILE} exist. Not Downloading it"
    else 
        curl https://repo.anaconda.com/archive/Anaconda3-2020.02-Linux-x86_64.sh --output ${ANACONDA_FILE}
    fi
    sh ${ANACONDA_FILE} -u -b -p ${ANACONDA_HOME}

    # Add conda commands to PATH
    echo "ANACONDA_HOME=${ANACONDA_HOME}" >> /etc/bash.bashrc
    echo 'export PATH=${ANACONDA_HOME}/bin:${PATH}' >> /etc/bash.bashrc

    # Anaconda Group
    groupadd ${ANACONDA_GROUP}
    chgrp -R ${ANACONDA_GROUP} ${ANACONDA_HOME}
    chmod 775 -R ${ANACONDA_HOME}
    if [[ $(echo "${OS}" | tr a-z A-Z) =~ ^(CENTOS|REDHAT)$ ]]; then
        useradd -g ${ANACONDA_GROUP} ${EXEC_USER} || true
        echo "Centos. User ${EXEC_USER} added to ${ANACONDA_GROUP}"
    else         
        adduser ${EXEC_USER} ${ANACONDA_GROUP} || true
        echo "Others. User ${EXEC_USER} added to ${ANACONDA_GROUP}"
    fi

    echo "Anaconda successfully installed"
}

# Install Miniconda
function install_miniconda()
{
    echo "Starting installing Miniconda"
    MINICONDA_FILE="Miniconda3-py37_4.8.2-Linux-x86_64.sh"
    MINICONDA_FILE_PATH="${TMP_DIR}/${MINICONDA_FILE}"
    if [ -f "${MINICONDA_FILE_PATH}" ]; then
        echo "${MINICONDA_FILE_PATH} exist. Not Downloading it"
    else 
        wget -O ${MINICONDA_FILE_PATH} https://repo.anaconda.com/miniconda/${MINICONDA_FILE}
    fi
    sh ${MINICONDA_FILE_PATH} -u -b -p ${MINICONDA_HOME}


 
    # Anaconda Group
    groupadd ${CONDA_GROUP}
    chgrp -R ${CONDA_GROUP} ${MINICONDA_HOME}
    chmod 775 -R ${MINICONDA_HOME}

    if [[ $(echo "${OS}" | tr a-z A-Z) =~ ^(CENTOS|REDHAT)$ ]]; then

        # Add conda commands to PATH
        PATH_SUB_FILE="/etc/bashrc"
        sed -i "s+MINICONDA_HOME=${MINICONDA_HOME}++g" ${PATH_SUB_FILE}
        sed -i 's+export PATH=${MINICONDA_HOME}/bin:${PATH}++g' ${PATH_SUB_FILE}  
        echo "MINICONDA_HOME=${MINICONDA_HOME}" >> ${PATH_SUB_FILE}
        echo 'export PATH=${MINICONDA_HOME}/bin:${PATH}' >> ${PATH_SUB_FILE} 

        usermod -a -G ${CONDA_GROUP} ${EXEC_USER}
        #useradd -g ${CONDA_GROUP} ${EXEC_USER} || true
        echo "Centos. User ${EXEC_USER} added to ${CONDA_GROUP}"
    else  
        # Add conda commands to PATH
        PATH_SUB_FILE="/etc/bash.bashrc"
        sed -i "s+MINICONDA_HOME=${MINICONDA_HOME}++g" ${PATH_SUB_FILE}
        sed -i 's+export PATH=${MINICONDA_HOME}/bin:${PATH}++g' ${PATH_SUB_FILE}  
        echo "MINICONDA_HOME=${MINICONDA_HOME}" >> ${PATH_SUB_FILE}
        echo 'export PATH=${MINICONDA_HOME}/bin:${PATH}' >> ${PATH_SUB_FILE} 

        #adduser ${EXEC_USER} ${CONDA_GROUP} || true
        usermod -a -G ${CONDA_GROUP} ${EXEC_USER}
        echo "Others. User ${EXEC_USER} added to ${CONDA_GROUP}"
    fi

    echo "Miniconda successfully installed"
}



# Create Virtual Env
function create_noronha_virtual_env()
{
    echo "Creating noronha virtual env"
    rm -rf "${NHA_VENV}"
    ${CONDA_HOME}/bin/conda create --prefix="${NHA_VENV}" python="3.7" -y
    chgrp -R ${CONDA_GROUP} ${NHA_VENV}
    source ${CONDA_HOME}/bin/activate ${NHA_VENV}
    echo "Noronha virtual env successfully installed"
}

function install_docker()
{
    echo "Starting installing docker"
    DOCKER_INST_FILE=${TMP_DIR}/install_docker.sh
    if [ -f "${DOCKER_INST_FILE}" ]; then
        echo "${DOCKER_INST_FILE} exist. Not Downloading it"
    else 
        curl -fsSL https://get.docker.com -o ${DOCKER_INST_FILE}
    fi
    sh ${DOCKER_INST_FILE}

    echo "Docker successfully installed"
}

# Create Docker group and init swarm mode
function activate_swarm_mode()
{
    echo "Starting activating swarm mode"
    /usr/sbin/usermod -aG docker ${EXEC_USER}
    docker swarm init || true
    echo "Swarm mode successfully activated"
}




# Install Noronha 
function install_noronha()
{
    echo "Starting installing Noronha Dataops"
    # Install dependencies
    ${PIP_HOME}/pip install --upgrade requests
    ${PIP_HOME}/pip install six==1.10.0
    ${PIP_HOME}/pip install --upgrade setuptools

    rm -rf ${NORONHA_INST_FOLDER}
    mkdir -p ${NORONHA_INST_FOLDER}
    cp -rf ${BASEDIR}/../* ${NORONHA_INST_FOLDER}/

    # Install Noronha
    ${PIP_HOME}/pip install ${NORONHA_INST_FOLDER}

    # Build Noronha Image
    docker build -f "${NORONHA_INST_FOLDER}/Dockerfile" -t "noronha.everis.ai/noronha:${NORONHA_BRANCH}" ${NORONHA_INST_FOLDER}

    # Add NHA_VENV to all users
    echo "export NHA_VENV=${NHA_VENV}" >> /etc/bash.bashrc
    # chown -R ${EXEC_USER} /home/${EXEC_USER}/.conda

    echo "Anaconda successfully installed"

    echo "Noronha Dataops successfully installed"
}

get_os_version && \
set_exec_user && \
install_miniconda && \
create_noronha_virtual_env && \
install_docker && \
activate_swarm_mode && \
install_noronha && \
echo "You must reboot this machine to the changes take effect"