pipeline {
    agent any

    stages {
        stage('Git Checkout') {
            steps {
                git branch: 'main', credentialsId: 'git-token', url: 'https://github.com/jaiswaladi246/Capstone-DotNET-Mongo-CD.git'
            }
        }
        
        stage('Deploy To Kubernetes') {
            steps {
                script {
                    withKubeConfig(caCertificate: '', clusterName: 'devopsshack-cluster', contextName: '', credentialsId: 'k8s-token', namespace: 'webapps', restrictKubeConfigAccess: false, serverUrl: 'https://D5E7BBA4E37876C9B7A541997A84D83D.gr7.ap-south-1.eks.amazonaws.com') {
                        sh 'kubectl apply -f Manifest/manifest.yaml -n webapps'
                        sh 'kubectl apply -f Manifest/ci.yaml'
                        sh 'kubectl apply -f Manifest/ingress.yaml -n webapps'
                        sleep 30
                    }
                }
            }
        }
        
         stage('Verify The Deployment') {
            steps {
                script {
                    withKubeConfig(caCertificate: '', clusterName: 'devopsshack-cluster', contextName: '', credentialsId: 'k8s-token', namespace: 'webapps', restrictKubeConfigAccess: false, serverUrl: 'https://D5E7BBA4E37876C9B7A541997A84D83D.gr7.ap-south-1.eks.amazonaws.com') {
                        sh 'kubectl get pods -n webapps'
                        sh 'kubectl get svc -n webapps'
                        sh 'kubectl get ingress -n webapps'
                        sleep 30
                    }
                }
            }
        }
        
    }
    post {
    always {
        script {
            def jobName = env.JOB_NAME
            def buildNumber = env.BUILD_NUMBER
            def pipelineStatus = currentBuild.result ?: 'UNKNOWN'
            def bannerColor = pipelineStatus.toUpperCase() == 'SUCCESS' ? 'green' : 'red'

            def body = """
                <html>
                <body>
                <div style="border: 4px solid ${bannerColor}; padding: 10px;">
                <h2>${jobName} - Build ${buildNumber}</h2>
                <div style="background-color: ${bannerColor}; padding: 10px;">
                <h3 style="color: white;">Pipeline Status: ${pipelineStatus.toUpperCase()}</h3>
                </div>
                <p>Check the <a href="${BUILD_URL}">console output</a>.</p>
                </div>
                </body>
                </html>
            """

            emailext (
                subject: "${jobName} - Build ${buildNumber} - ${pipelineStatus.toUpperCase()}",
                body: body,
                to: '567adddi.jais@gmail.com',
                from: 'jaiswaladi246@gmail.com',
                replyTo: 'jenkins@devopsshack.com',
                mimeType: 'text/html',
               
            )
        }
    }
}
}


