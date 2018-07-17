#!/bin/bash
echo "Deleting Service Role"
aws cloudformation delete-stack --stack-name eks-service-role
sleep 10
echo "Deleting EKS Workers"
aws cloudformation delete-stack --stack-name EKS-Workers
sleep 10
echo "Deleting EKS Cluster"
aws eks delete-cluster --name EKS-Cluster
sleep 10
echo "Deleting EKS VPC"
aws cloudformation delete-stack --stack-name EKS-Test
sleep 10