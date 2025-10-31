#!/bin/bash
# Update packages and install dependencies
sudo yum update -y
sudo yum install -y git java-21-amazon-corretto-devel maven

# Clone the GitHub repository
cd /home/ec2-user
git clone https://github.com/Trainings-TechEazy/test-repo-for-devops.git
cd test-repo-for-devops

# Build the application
mvn clean package

# Run the app in background
nohup java -jar target/hellomvc-0.0.1-SNAPSHOT.jar > app.log 2>&1 &

# Wait a few seconds to let the app start
sleep 15

# 🔍 Test if app is reachable on port 80
echo "Testing if the app is reachable on port 80..."
if curl -s -I http://localhost:80 | grep "200 OK" > /dev/null; then
    echo "✅ App is running and reachable on port 80"
else
    echo "❌ App not reachable on port 80"
fi

# 💰 Stop instance after a set time (for cost saving)
# This will shut down the instance after 30 minutes
echo "Instance will shut down automatically after 30 minutes to save cost."
sudo shutdown -h +5
