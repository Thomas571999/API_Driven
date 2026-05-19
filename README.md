------------------------------------------------------------------------------------------------------
ATELIER API-DRIVEN INFRASTRUCTURE
------------------------------------------------------------------------------------------------------
L’idée en 30 secondes : **Orchestration de services AWS via API Gateway et Lambda dans un environnement émulé**.  
Cet atelier propose de concevoir une architecture **API-driven** dans laquelle une requête HTTP déclenche, via **API Gateway** et une **fonction Lambda**, des actions d’infrastructure sur des **instances EC2**, le tout dans un **environnement AWS simulé avec LocalStack** et exécuté dans **GitHub Codespaces**. L’objectif est de comprendre comment des services cloud serverless peuvent piloter dynamiquement des ressources d’infrastructure, indépendamment de toute console graphique.Cet atelier propose de concevoir une architecture API-driven dans laquelle une requête HTTP déclenche, via API Gateway et une fonction Lambda, des actions d’infrastructure sur des instances EC2, le tout dans un environnement AWS simulé avec LocalStack et exécuté dans GitHub Codespaces. L’objectif est de comprendre comment des services cloud serverless peuvent piloter dynamiquement des ressources d’infrastructure, indépendamment de toute console graphique.
  
-------------------------------------------------------------------------------------------------------
Séquence 1 : Codespace de Github
-------------------------------------------------------------------------------------------------------
Objectif : Création d'un Codespace Github  
Difficulté : Très facile (~5 minutes)
-------------------------------------------------------------------------------------------------------
RDV sur Codespace de Github : <a href="https://github.com/features/codespaces" target="_blank">Codespace</a> **(click droit ouvrir dans un nouvel onglet)** puis créer un nouveau Codespace qui sera connecté à votre Repository API-Driven.
  
---------------------------------------------------
Séquence 2 : Création de l'environnement AWS (LocalStack)
---------------------------------------------------
Objectif : Créer l'environnement AWS simulé avec LocalStack  
Difficulté : Simple (~5 minutes)
---------------------------------------------------

Dans le terminal du Codespace copier/coller les codes ci-dessous etape par étape :  

**Installation de l'émulateur LocalStack**  
```
sudo -i mkdir rep_localstack
```
```
sudo -i python3 -m venv ./rep_localstack
```
```
sudo -i pip install --upgrade pip && python3 -m pip install localstack && export S3_SKIP_SIGNATURE_VALIDATION=0
```
Rendez-vous chez Localstack pour vous créez un Token : https://app.localstack.cloud/
```
localstack auth set-token <YOUR_AUTH_TOKEN>
localstack start -d
```
**vérification des services disponibles**  
```
localstack status services
```
**Réccupération de l'API AWS Localstack** 
Votre environnement AWS (LocalStack) est prêt. Pour obtenir votre AWS_ENDPOINT cliquez sur l'onglet **[PORTS]** dans votre Codespace et rendez public votre port **4566** (Visibilité du port).
Réccupérer l'URL de ce port dans votre navigateur qui sera votre ENDPOINT AWS (c'est à dire votre environnement AWS).
Conservez bien cette URL car vous en aurez besoin par la suite.  

Pour information : IL n'y a rien dans votre navigateur et c'est normal car il s'agit d'une API AWS (Pas un développement Web type UX).

---------------------------------------------------
Séquence 3 : Exercice
---------------------------------------------------
Objectif : Piloter une instance EC2 via API Gateway
Difficulté : Moyen/Difficile (~2h)
---------------------------------------------------  
Votre mission (si vous l'acceptez) : Concevoir une architecture **API-driven** dans laquelle une requête HTTP déclenche, via **API Gateway** et une **fonction Lambda**, lancera ou stopera une **instance EC2** déposée dans **environnement AWS simulé avec LocalStack** et qui sera exécuté dans **GitHub Codespaces**. [Option] Remplacez l'instance EC2 par l'arrêt ou le lancement d'un Docker.  

**Architecture cible :** Ci-dessous, l'architecture cible souhaitée.   
  
![Screenshot Actions](API_Driven.png)   
  
---------------------------------------------------  
## Processus de travail (résumé)

1. Installation de l'environnement Localstack (Séquence 2)
2. Création de l'instance EC2
3. Création des API (+ fonction Lambda)
4. Ouverture des ports et vérification du fonctionnement

---------------------------------------------------
Séquence 4 : Documentation  
Difficulté : Facile (~30 minutes)
---------------------------------------------------
**Complétez et documentez ce fichier README.md** pour nous expliquer comment utiliser votre solution.  
Faites preuve de pédagogie et soyez clair dans vos expliquations et processus de travail.  
   
---------------------------------------------------
TRAVAIL RÉALISÉ :

# 🚀 API-Driven Infrastructure (AWS LocalStack)

## 📌 Objectif du projet

Ce projet a pour objectif de simuler une architecture **API-driven infrastructure** dans laquelle une requête HTTP déclenche des actions sur une instance EC2 via :

- API Gateway
- AWS Lambda
- EC2 (simulé via LocalStack)
- GitHub Codespaces

L'ensemble est exécuté dans un environnement AWS simulé grâce à **LocalStack**, sans utilisation de la console AWS.

---

## 🏗️ Architecture

Le flux global du projet est le suivant :

```
Client (curl / Makefile)
        ↓
API Gateway (LocalStack)
        ↓
AWS Lambda (ec2-controller)
        ↓
EC2 Instance (start / stop / status)
```

---

## ⚙️ Technologies utilisées

- AWS CLI (avec LocalStack)
- LocalStack (simulation AWS)
- AWS Lambda (Python 3.10)
- API Gateway (REST API)
- EC2 (instance simulée)
- Makefile (automatisation)
- GitHub Codespaces

---

## 🧪 Fonctionnalités

L'API permet de gérer une instance EC2 avec 3 actions :

| Action | Description |
|--------|-------------|
| `start`  | Démarrer l'instance |
| `stop`   | Arrêter l'instance |
| `status` | Vérifier l'état de l'instance |

---

## 🚀 Déploiement du projet

### 1. Lancer LocalStack

```bash
localstack start -d
```

Vérifier les services :

```bash
localstack status services
```

### 2. Variables d'environnement

Avant utilisation :

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
export API_ID=<your-api-id>
export EC2_RESOURCE_ID=<your-resource-id>
export ROOT_ID=<your-root-id>
```

### 3. Création de l'infrastructure AWS (LocalStack)

**API Gateway**

```bash
aws --endpoint-url=$AWS_ENDPOINT_URL apigateway create-rest-api --name ec2-api
```

**Déploiement Lambda**

```bash
make deploy-lambda
```

**Déploiement API**

```bash
aws --endpoint-url=$AWS_ENDPOINT_URL apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name dev
```

---

## 📡 Utilisation de l'API

### Stop instance

```bash
make stop
```

ou

```bash
curl -X POST \
  http://localhost:4566/restapis/$API_ID/dev/_user_request_/ec2 \
  -H "Content-Type: application/json" \
  -d '{"action":"stop"}'
```

### Start instance

```bash
make start
```

### Status instance

```bash
make status
```

---

## 🧠 Automatisation (Makefile)

| Commande | Description |
|----------|-------------|
| `make deploy-lambda` | Déploiement Lambda |
| `make test-all` | Test complet |
| `make validate` | Validation infrastructure |
| `make full` | Pipeline complet |
| `make clean` | Nettoyage |

---

## 🧪 Exemple de test complet

```bash
make test-all
```

Résultat attendu :

- ✅ Stop instance
- ✅ Start instance
- ✅ Status = running

---

## 📊 Validation du projet

```bash
make validate
```

Vérifie :

- ✅ EC2 instances
- ✅ Lambda function
- ✅ API Gateway

---

## 📁 Structure du projet

```
API_Driven/
│
├── lambda/
│   ├── lambda_function.py
│   └── lambda.zip
│
├── Makefile
├── init.sh
└── README.md
```

---

## 🎯 Résultat attendu

Ce projet démontre :

- ✅ Une architecture API-driven complète
- ✅ Une orchestration serverless (Lambda)
- ✅ Un contrôle d'infrastructure via HTTP
- ✅ Une simulation AWS via LocalStack
- ✅ Une automatisation via Makefile

---

## 🏁 Conclusion

Cette architecture illustre un flux cloud moderne :

```
Client HTTP → API Gateway → Lambda → EC2
```

Elle démontre la capacité à piloter une infrastructure cloud de manière totalement automatisée et programmatique.

---

## 👨‍💻 Auteur

Projet réalisé dans le cadre d'un atelier DevOps / AWS sur les architectures API-driven.

Evaluation
---------------------------------------------------
Cet atelier, **noté sur 20 points**, est évalué sur la base du barème suivant :  
- Repository exécutable sans erreur majeure (4 points)
- Fonctionnement conforme au scénario annoncé (4 points)
- Degré d'automatisation du projet (utilisation de Makefile ? script ? ...) (4 points)
- Qualité du Readme (lisibilité, erreur, ...) (4 points)
- Processus travail (quantité de commits, cohérence globale, interventions externes, ...) (4 points) 
