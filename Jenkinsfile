pipeline {
  agent any

  environment {
    AWS_REGION     = 'ap-south-1'
    AWS_ACCOUNT_ID = '624564777830'
    ECR_REPO       = 'devops-task'
    ECS_CLUSTER    = 'devops-cluster'
    ECS_SERVICE    = 'devops-service'
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Install & Test') {
      steps {
        sh 'npm ci'
      }
    }

    stage('Build Image') {
      steps {
        script {
          def shortCommit = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          env.IMAGE_TAG = "${env.BUILD_NUMBER}-${shortCommit}"

          if (!env.AWS_ACCOUNT_ID || env.AWS_ACCOUNT_ID.trim() == '') {
            env.AWS_ACCOUNT_ID = sh(script: "aws sts get-caller-identity --query Account --output text", returnStdout: true).trim()
            echo "Detected AWS account id: ${env.AWS_ACCOUNT_ID}"
          }

          env.IMAGE_URI = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com/${env.ECR_REPO}:${env.IMAGE_TAG}"
          echo "Building image ${env.IMAGE_URI}"
          sh "docker build -t ${env.IMAGE_URI} ."
        }
      }
    }

    stage('Login & Push to ECR') {
      steps {
        script {
          sh '''
            set -e
            # login using instance role (aws CLI will use instance profile)
            aws ecr get-login-password | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

            # ensure repo exists
            aws ecr describe-repositories --repository-names ${ECR_REPO} >/dev/null 2>&1 || aws ecr create-repository --repository-name ${ECR_REPO}

            # push the immutable tag
            docker push ${IMAGE_URI}

            # also tag as :latest and push that tag (so taskdefs referencing :latest pick up new image)
            LATEST_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest
            docker tag ${IMAGE_URI} ${LATEST_URI}
            docker push ${LATEST_URI}
          '''
        }
      }
    }

    stage('Deploy to ECS') {
      steps {
        script {
          sh '''
          set -e
          export AWS_DEFAULT_REGION=${AWS_REGION}

          echo "Preparing task definition with new image: ${IMAGE_URI}"
          sed "s|REPLACABLE_URL|${IMAGE_URI}|g" taskdef.json > taskdef-rendered.json

          echo "Registering new task definition..."
          aws ecs register-task-definition --cli-input-json file://taskdef-rendered.json

          echo "Updating service ${ECS_SERVICE} in cluster ${ECS_CLUSTER}"
          aws ecs update-service --cluster ${ECS_CLUSTER} --service ${ECS_SERVICE} --force-new-deployment
          '''
        }
      }
    }
  }

  post {
    always {
      echo "Pipeline finished. IMAGE_URI=${env.IMAGE_URI} (and pushed :latest)"
    }
  }
}
