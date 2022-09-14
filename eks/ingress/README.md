# Ingress 문법 정리 (ver. EKS)

apiVersion: networking.k8s.io/v1

kind: Ingress

## [metadata](https://kubernetes.io/docs/reference/kubernetes-api/common-definitions/object-meta/#ObjectMeta)

- name: 해당 Ingress의 이름, 네임스페이스 내에서 고유해야 하며 멱등성을 위해 수정 불가능함.
- namespace: 소속될 네임스페이스 정의, 입력되지 않을 경우 "default" 네임스페이스에 들어가게 됨.

### [annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/annotations/)

ingress는 어노테이션을 통해 다양한 스펙 설정이 가능함. AWS ALB에서 거의 필수적으로 해야하는 건 다음과 같음.

- kubernetes.io/ingress.class: **alb**
  - Ingress 클래스의 이름을 정의함. 문서에는 이것이 `spec.ingressClassName`과 대응된다고 기재되어 있음.
  - 보통 Ingress는 ALB를 쓰므로 아래와 같이 약속같이 써줌.
- alb.ingress.kubernetes.io/load-balancer-name: <AWS ALB 이름>, 32자보다 긴 이름은 오류로 처리
- alb.ingress.kubernetes.io/scheme: (**internal, internet-facing**)
  - ALB가 외부 노출이 될 것인지 아닌지 결정.
- alb.ingress.kubernetes.io/target-type: (ip, instance)
  - ip: pod IP에 직접 접근한다. (**[sticky session](https://smjeon.dev/web/sticky-session/)을 사용하려면 반드시 IP 모드를 사용해야 함**)
  - instance: Nodeport 모드로 열린 서비스를 통해 인스턴스에 접근함.

## spec

### rules: http: paths: []

- path: "/", 경로 
- pathType: (**Prefix, Exact, ImplementationSpecific**), path 인자를 통해 어떻게 필터링을 할지 결정
- backend
  - service: 연결할 서비스
    - name: 서비스 이름
    - port:
      - number: 포트 숫자



# References

https://kubernetes.io/docs/reference/kubernetes-api/service-resources/ingress-v1/

https://whchoi98.gitbook.io/k8s/5.eks-ingress/alb-ingress#12.ingress-annotation