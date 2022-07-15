#!/bin/bash
clear
generate_crypto=false
install_SC=false
deploy_Network=false
DEFAULT_PWD=$(pwd)


chmod -R 766 * #rwx rw rw
# test if crypto-config folder exists
if [ ! -d "crypto-config" ]; then
    generate_crypto=true
fi


# parse flags
while [[ $# -ge 1 ]] ; do
  key="$1"
  case $key in
  -h )
    printHelp $MODE
    exit 0
    ;;
  -installSC )
    install_SC=true
    shift
    ;;
  -crypto )
    generate_crypto=true
    shift
    ;;
    -deploy )
    deploy_Network=true
    shift
    ;;
    -a ) # all
    generate_crypto=true
    deploy_Network=true
    install_SC=true
    shift
    ;;
  * )
    errorln "Unknown flag: $key"
    printHelp
    exit 1
    ;;
  esac
  shift
done

# function to print help
function printHelp {
  echo "Usage: ./network.sh [-h] [-crypto] [-installSC] [-deploy]"
  echo "  -h: Prints help"
  echo "  -crypto: Generates crypto material"
  echo "  -installSC: Compiles and installs the Smart Contract(PRECECTSC)"
  echo "  -deploy: Deploys the network (to delete existing network run -crypto and the script will understand you want to delete everything and start from zero)"
  echo "  -a: (all): Generates crypto material and installs the Smart Contract and deploys the network"
}



#function named generate crypto-config
function generateCryptoConfig {
    # delete crypto-config folder if it exists
    if [ -d "crypto-config" ]; then
        rm -rf crypto-config
    fi
    cd crypto-config-source/scripts
    echo "1- generate crypto material and config files"
    echo "."
    echo "."
    echo "."
    bash generarFicherosTx.sh
    if [ "$?" -ne 0 ]; then
        echo "Failed to generate crypto material..."
        exit 1
    fi
    echo
    echo "Generate crypto material completed."

    cd $DEFAULT_PWD
    ls -l crypto-config 
    echo "2- put files on necessary directories"
    echo "copying crypto config and channel artifacts to docker folder"
    cp -r crypto-config channel-artifacts docker-compose-files/

    echo "copying crypto to ChainREST and blockchain explorer folders"
    cp -r crypto-config ../ChainREST
    cp -r crypto-config ../blockchain-explorer

    echo "copying new user X.509 identity to ChainREST files"
    #replace line break of a file for a "\n" character in a new file
    certificate=$( sed  -z -e 's|\n|\\\\n|g' ./crypto-config/peerOrganizations/org1.odins.com/users/User1@org1.odins.com/msp/signcerts/User1@org1.odins.com-cert.pem)
    priv=$(sed  -z -e 's|\n|\\\\n|g' ./crypto-config/peerOrganizations/org1.odins.com/users/User1@org1.odins.com/msp/keystore/priv_sk)
    #replace whole line containning substring "x" with "newline"
    s1="s|certificate:.*///|certificate:\"$certificate\",///|g"
    s2="s|certificate:.*///|certificate:\"$certificate\",///|g"
    s3="s|privateKey:.*///|privateKey:\"$priv\",///|g"
    s4="s|privateKey:.*///|privateKey:\"$priv\",///|g"
    sed  -i -r "$s1" ../ChainREST/routes/worker-get.js
    sed  -i -r "$s2" ../ChainREST/routes/worker-put.js
    sed  -i -r "$s3" ../ChainREST/routes/worker-get.js
    sed  -i -r "$s4" ../ChainREST/routes/worker-put.js 

    echo "Did it work?"
    echo " certificate from crypto-config: " $certificate

    echo " grep certificate from ChainREST/routes/worker-get.js: " $(grep  CERTIFICATE ../ChainREST/routes/worker-get.js)

        echo " private key from crypto-config: " $priv
    echo " grep private key from ChainREST/routes/worker-get.js: " $(grep PRIVATE ../ChainREST/routes/worker-get.js)
    #bash redirect error output to /dev/null

  cd $DEFAULT_PWD
}

# function to deploy hyperledger fabric blockchain network
function deployNetwork {
  echo "3- deploy blockchain network"
  #test if crypto-config folder exists, if not, run generateCryptoConfig function
  if [ ! -d "crypto-config" ]; then
      generateCryptoConfig
  fi

  cd docker-compose-files/scripts
  echo " running script to deploy blockchain network"
  if [ "$generate_crypto" = true ]; then
    echo "-crypto flag was set, so we will delete everything and start from scratch"
    bash BorrarYLanzarBlockchain.sh
  else
    bash ReLanzarBlockchain.sh
  fi


  cd $DEFAULT_PWD
}

function installSC {
  echo "4- install smart contract"
  cd chaincode/PreceptSC
  echo "compiling smart contract"
  ./gradlew installDist
  cd build/install
  rm -r ../../../../docker-compose-files/chaincode/PreceptSC
  cp -r PreceptSC ../../../../docker-compose-files/chaincode/PreceptSC

  echo "running script to install smartcontract on peer container"
  #run script installSC on container named cli and redirect error to output
  docker exec -it cli "sh scripts/installSC.sh PreceptSC 1" 2>&1 

}
if [ "$generate_crypto" = true ]; then
    echo "Generating crypto material..."
    generateCryptoConfig
fi

if [ "$deploy_Network" = true ]; then
    echo "Deploying network..."
    deployNetwork
fi

if [ "$install_SC" = true ]; then
    echo "Installing smart contract..."
    installSC
fi